import AppKit
import CoreGraphics
import os
import TabletKit

extension InputInjector {

    // MARK: - Pen injection

    func inject(point: TabletPoint, settings: TabletSettings?) {
        rearmWatchdog()
        guard let snap = injectionSnapshot else { return }
        let tool = snap.activeTool
        var point = point

        guard let rawPoint = resolveRawPoint(point: &point, snap: snap) else { return }

        let rawPressure = InputInjector.curvedPressure(
            point.normalizedPressure, lut: tool.pressureLUT)
        let tipDown = resolveTipDown(point: point, rawPressure: rawPressure)

        let pressure = applyPressureSmoothing(rawPressure: rawPressure, tipDown: tipDown)

        if handleXencelabsDebounce(point: point, snap: snap) { return }

        let enteringProximity = point.inProximity && !lastProximity
        handleProximityTransitions(point: point, rawPoint: rawPoint, tool: tool, snap: snap)

        guard point.inProximity else { return }

        let screenPoint = smoother.applySmoothing(
            rawPoint: rawPoint, enteringProximity: enteringProximity)

        processScrollDrag(screenPoint: screenPoint)

        let pose = resolveEffectivePose(point: point, snapshot: snap)
        shimLastPoint = point
        shimLastScreen = screenPoint
        shimLastPressure = pressure

        observeHover(tipDown: tipDown, rawPoint: rawPoint)

        handleTipTransitions(
            tipDown: tipDown, screenPoint: screenPoint, pressure: pressure,
            pose: pose, point: point, snap: snap, tool: tool)

        handlePenButtonTransitions(
            point: point, screenPoint: screenPoint,
            snap: snap, settings: settings, tool: tool)

        handleMouseToolTransitions(point: point, screenPoint: screenPoint)
    }

    private func resolveRawPoint(point: inout TabletPoint, snap: InjectionSnapshot) -> CGPoint? {
        if snap.invertRotation && point.rotation != 0.0 {
            point.rotation = (360.0 - point.rotation).truncatingRemainder(dividingBy: 360.0)
        }
        if snap.relativeCursorMovement {
            if point.inProximity {
                return displayMapper.resolveRelativePoint(
                    point, snapshot: snap, currentCursorPosition: currentCursorPosition(),
                    deviceProductID: deviceProductID)
            } else {
                return currentCursorPosition()
            }
        } else {
            guard let absPoint = displayMapper.mapToScreen(
                point, snapshot: snap, deviceProductID: deviceProductID)
            else {
                displayMapper.clearRelativeAnchor()
                return nil
            }
            return Self.pinNearScreenEdges(
                absPoint, in: displayMapper.displayBounds(for: snap))
        }
    }

    private func resolveTipDown(point: TabletPoint, rawPressure: Double) -> Bool {
        return activeToolIsMouse
            ? (usbMouseLeftHeld ? false : point.penButton1)
            : rawPressure > InputInjector.tipPressureThreshold
    }

    private func applyPressureSmoothing(rawPressure: Double, tipDown: Bool) -> Double {
        if tipDown {
            return pressureSmoother.applySmoothing(
                rawPressure: rawPressure, strokeStarting: !lastTipDown)
        } else {
            pressureSmoother.reset()
            return rawPressure
        }
    }

    private func handleXencelabsDebounce(point: TabletPoint, snap: InjectionSnapshot) -> Bool {
        guard deviceVendorID == 0x28BD else { return false }
        if point.inProximity {
            if let timer = proximityExitDebounceTimer {
                CFRunLoopTimerInvalidate(timer)
                proximityExitDebounceTimer = nil
            }
        } else if lastProximity && proximityExitDebounceTimer == nil {
            let anyButtonHeld =
                lastTipDown || lastButton1Down || lastButton2Down || lastButton3Down
                || lastMiddleDown || usbMouseLeftHeld || lastUSBMouseMask != 0
            let delay = anyButtonHeld
                ? proximityExitHeldButtonSafetyInterval : proximityExitDebounceInterval
            if anyButtonHeld {
                button1UpDebounceTimer.map { CFRunLoopTimerInvalidate($0) }
                button1UpDebounceTimer = nil
                button2UpDebounceTimer.map { CFRunLoopTimerInvalidate($0) }
                button2UpDebounceTimer = nil
                button3UpDebounceTimer.map { CFRunLoopTimerInvalidate($0) }
                button3UpDebounceTimer = nil
            }
            let timer = CFRunLoopTimerCreateWithHandler(
                kCFAllocatorDefault,
                CFAbsoluteTimeGetCurrent() + delay,
                0, 0, 0
            ) { [weak self] _ in
                guard let self else { return }
                self.proximityExitDebounceTimer = nil
                self.commitProximityExit(snap: snap)
            }
            CFRunLoopAddTimer(HIDThread.shared.runLoop, timer, .commonModes)
            proximityExitDebounceTimer = timer
            return true
        }
        return false
    }

    private func handleProximityTransitions(
        point: TabletPoint, rawPoint: CGPoint, tool: InjectionSnapshot.Tool, snap: InjectionSnapshot
    ) {
        let eraserFlipped = point.inProximity && lastProximity && (point.eraser != lastEraserMode)

        if point.inProximity != lastProximity {
            if activeAppProfile == .generic {
                postProximityEvent(
                    entering: point.inProximity, at: rawPoint,
                    eraser: point.eraser)
            }
            if point.inProximity {
                activeToolIsEraser = point.eraser
                lastEraserMode = point.eraser
                smoother.smoothingStrength = tool.smoothingStrength
                pressureSmoother.smoothingStrength = tool.pressureSmoothingStrength
                lastProximity = true
            } else {
                commitProximityExit(snap: snap)
            }
        }

        if eraserFlipped {
            postProximityEvent(entering: false, at: rawPoint, eraser: !point.eraser)
            activeToolIsEraser = point.eraser
            lastEraserMode = point.eraser
            postProximityEvent(entering: true, at: rawPoint, eraser: point.eraser)
        }
    }

    private func processScrollDrag(screenPoint: CGPoint) {
        let panNow = CFAbsoluteTimeGetCurrent()
        let panDt = lastPanScrollFrameTime > 0 ? panNow - lastPanScrollFrameTime : 0
        lastPanScrollFrameTime = panNow
        if panScroll.isActive {
            postPanScroll(panScroll.process(screen: screenPoint, dt: panDt))
        }
    }

    private func observeHover(tipDown: Bool, rawPoint: CGPoint) {
        if !tipDown {
            smoother.observeHoverRaw(rawPoint)
        } else {
            smoother.endHover()
        }
    }

    private func handleTipTransitions(
        tipDown: Bool, screenPoint: CGPoint, pressure: Double, pose: (tiltX: Double, tiltY: Double, rotation: Double),
        point: TabletPoint, snap: InjectionSnapshot, tool: InjectionSnapshot.Tool
    ) {
        if tipDown != lastTipDown {
            if !activeToolIsMouse && activeAppNeedsTabletPointerEvents {
                postTabletPointerEvent(
                    at: screenPoint, pressure: pressure, point: point, pose: pose,
                    snapshot: snap)
            }
            if tipDown {
                cancelPendingMouseUp()
                didEmitDragSinceDown = false
                if panScroll.isActive {
                    // Swallow the mouseDown so a touch doesn't start a selection or fire
                } else {
                    let tipAction = activeToolIsEraser ? tool.eraserBinding : tool.tipBinding
                    activeButton = tipAction.mouseButton ?? .left
                    let (clickPt, count) = resolveClick(screenPoint, snapshot: snap)
                    activeClickCount = count
                    tipDownOrigin = clickPt
                    postMouseDown(
                        button: activeButton, at: clickPt,
                        pressure: pressure, clickCount: count,
                        point: point,
                        snapshot: snap)
                }
            } else {
                if panScroll.isActive {
                    // Symmetric to the swallowed mouseDown
                } else {
                    let btn = activeButton
                    let count = activeClickCount
                    let pt = point

                    if activeAppProfile == .generic
                        && snap.tipUpAssistDelay > 0
                        && smoother.recentVelocity > Self.tipUpAssistVelocityThreshold {
                        let capturedSnap = snap
                        let timer = CFRunLoopTimerCreateWithHandler(
                            kCFAllocatorDefault,
                            CFAbsoluteTimeGetCurrent() + snap.tipUpAssistDelay / 1000.0,
                            0, 0, 0
                        ) { [weak self] _ in
                            guard let self, self.pendingMouseUp != nil else { return }
                            self.pendingMouseUp = nil
                            self.postMouseUp(
                                button: btn, at: self.lastPostedPoint, clickCount: count,
                                point: pt, snapshot: capturedSnap)
                        }
                        pendingMouseUp = timer
                        if let timer {
                            CFRunLoopAddTimer(HIDThread.shared.runLoop, timer, .commonModes)
                        }
                    } else {
                        postMouseUp(
                            button: activeButton, at: screenPoint,
                            clickCount: activeClickCount, point: point,
                            snapshot: snap)
                    }
                }
            }
            lastPostedPoint = screenPoint
            lastPostedPressure = pressure
            hasPostedPoint = true

        } else if panScroll.isActive {
            if hasPostedPoint {
                let delta = hypot(
                    screenPoint.x - lastPostedPoint.x,
                    screenPoint.y - lastPostedPoint.y)
                smoother.recordMoveDelta(delta)
            }
            lastPostedPoint = screenPoint
            lastPostedPressure = pressure
            hasPostedPoint = true

        } else {
            handleContinuousMovement(
                screenPoint: screenPoint, pressure: pressure, tipDown: tipDown,
                pose: pose, point: point, snap: snap)
        }
        lastTipDown = tipDown
    }

    private func handleContinuousMovement(
        screenPoint: CGPoint, pressure: Double, tipDown: Bool,
        pose: (tiltX: Double, tiltY: Double, rotation: Double),
        point: TabletPoint, snap: InjectionSnapshot
    ) {
        let moved =
            !hasPostedPoint
            || (screenPoint.x - lastPostedPoint.x).magnitude > Self.positionEpsilon
            || (screenPoint.y - lastPostedPoint.y).magnitude > Self.positionEpsilon
            || (tipDown && activeAppProfile != .finderPlainMouse
                && (pressure - lastPostedPressure).magnitude > Self.pressureEpsilon)

        let dragging = tipDown || (activeToolIsMouse && usbMouseLeftHeld)
        let forceFirstDrag = dragging && activeAppProfile == .pagesPlainMouse && !didEmitDragSinceDown

        if moved || forceFirstDrag {
            if hasPostedPoint {
                let delta = hypot(
                    screenPoint.x - lastPostedPoint.x,
                    screenPoint.y - lastPostedPoint.y)
                smoother.recordMoveDelta(delta)
            }
            if !activeToolIsMouse && activeAppNeedsTabletPointerEvents {
                postTabletPointerEvent(
                    at: screenPoint, pressure: pressure, point: point, pose: pose,
                    snapshot: snap)
            }
            let withinDragThreshold =
                tipDown && !didEmitDragSinceDown && !forceFirstDrag
                && snap.dragThreshold > 0
                && hypot(screenPoint.x - tipDownOrigin.x, screenPoint.y - tipDownOrigin.y)
                    < snap.dragThreshold

            if dragging {
                if !withinDragThreshold {
                    postMouseDrag(
                        button: activeButton, at: screenPoint, pressure: pressure, point: point,
                        pose: pose, snapshot: snap)
                    didEmitDragSinceDown = true
                }
            } else if panScroll.isActive {
                // Scroll Drag held: pen motion became scroll deltas above
            } else if let dragBtn = hoverDragButton {
                postMouseDrag(
                    button: dragBtn, at: screenPoint, pressure: 0, point: point,
                    pose: pose, snapshot: snap)
            } else {
                postMouseMoved(
                    at: screenPoint, point: point, pose: pose,
                    snapshot: snap)
            }
            lastPostedPoint = screenPoint
            lastPostedPressure = pressure
            hasPostedPoint = true
        }
    }

    private func handlePenButtonTransitions(
        point: TabletPoint, screenPoint: CGPoint,
        snap: InjectionSnapshot, settings: TabletSettings?, tool: InjectionSnapshot.Tool
    ) {
        let btn1 = tool.penButton1Binding
        let btn2 = tool.penButton2Binding
        let btn3 = tool.penButton3Binding

        if deviceVendorID == 0x28BD {
            if !activeToolIsMouse {
                handleXencelabsBarrelButton(
                    slot: .one, down: point.penButton1, binding: btn1,
                    at: screenPoint, snap: snap, settings: settings)
                handleXencelabsBarrelButton(
                    slot: .three, down: point.penButton3, binding: btn3,
                    at: screenPoint, snap: snap, settings: settings)
            } else {
                lastButton1Down = point.penButton1
            }
            handleXencelabsBarrelButton(
                slot: .two, down: point.penButton2, binding: btn2,
                at: screenPoint, snap: snap, settings: settings)
        } else {
            if point.penButton1 != lastButton1Down {
                lastButton1Down = point.penButton1
                if !activeToolIsMouse {
                    fireButtonAction(btn1, down: point.penButton1, at: screenPoint,
                                     snapshot: snap, settings: settings)
                }
            }
            if point.penButton2 != lastButton2Down {
                lastButton2Down = point.penButton2
                fireButtonAction(btn2, down: point.penButton2, at: screenPoint,
                                 snapshot: snap, settings: settings)
            }
        }
    }

    private func handleMouseToolTransitions(point: TabletPoint, screenPoint: CGPoint) {
        if point.mouseMiddleButton != lastMiddleDown {
            let type: CGEventType = point.mouseMiddleButton ? .otherMouseDown : .otherMouseUp
            if let e = CGEvent(
                mouseEventSource: sessionSource, mouseType: type,
                mouseCursorPosition: screenPoint, mouseButton: .center)
            {
                e.flags = currentEventFlags
                finalizeAndPost(e)
            }
            lastMiddleDown = point.mouseMiddleButton
        }

        if point.mouseWheelDelta != 0 {
            postScrollWheelEvent(delta: point.mouseWheelDelta, at: screenPoint)
        }
    }
