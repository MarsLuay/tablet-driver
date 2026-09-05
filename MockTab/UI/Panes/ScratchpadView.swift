// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AppKit
import Combine
import OSLog
import TabletKit

private let scratchpadLog = Logger(subsystem: "com.cyzor.mocktab", category: "scratchpad")

// MARK: - SwiftUI wrapper

struct ScratchpadView: View {
    @ObservedObject var settings: TabletSettings
    @ObservedObject var tabletManager: TabletManager
    @ObservedObject var registry: DeviceRegistry
    /// Deliberately NOT @ObservedObject: the ~30 Hz touch-frame stream must
    /// invalidate only the small `TouchVisualizer` child (which observes the
    /// publisher itself), not this whole pane — re-evaluating the full body
    /// per frame was a measurable main-thread CPU cost while touch was live.
    /// This view only writes gating state (`isPublishingEnabled`, clearing
    /// `contacts`); it never reads `contacts` in `body`.
    private let liveTouch: LiveTouchPublisher
    let instanceKey: DeviceInstanceKey?
    /// Model axis of the bound unit — spec/catalog lookups key on this.
    private var productID: Int? { instanceKey?.productID }
    var undoManager: UndoManager?

    init(settings: TabletSettings,
         tabletManager: TabletManager,
         registry: DeviceRegistry,
         instanceKey: DeviceInstanceKey? = nil,
         undoManager: UndoManager? = nil) {
        self.settings = settings
        self.tabletManager = tabletManager
        self.registry = registry
        self.instanceKey = instanceKey
        self.undoManager = undoManager
        // Derive the touch publisher from the bound manager so the view isn't
        // tied to the singleton — the only `TabletManager` in practice today,
        // but the parameter is what the rest of the view uses.
        self.liveTouch = tabletManager.liveTouch
    }

    @State private var currentPressure: Double = 0
    @State private var clearID = 0
    @State private var resetViewportID = 0
    @State private var canvasZoom = 1.0

    /// Tracks whether this view is on-screen AND the app is frontmost.
    /// Used to gate the live-touch publish — when either is false, the
    /// HID-thread closure skips dispatch entirely, so a palm resting on
    /// the tablet costs nothing while the user is in another tab or app.
    @State private var isVisible = false
    @State private var isAppActive = NSApp.isActive

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()

            DeviceStatusBar(
                settings: settings,
                tabletManager: tabletManager,
                registry: registry,
                instanceKey: instanceKey
            )
            .layoutPriority(1)
        }
        .onAppear {
            isVisible = true
            updateLiveTouchGate()
        }
        .onDisappear {
            isVisible = false
            updateLiveTouchGate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
            updateLiveTouchGate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isAppActive = false
            updateLiveTouchGate()
        }
        .onChange(of: settings.touchEnabled) { enabled in
            // The HID closure stops publishing immediately when touch is
            // disabled, but the previously displayed contacts would otherwise
            // linger on the canvas with no fresh frame to overwrite them.
            if !enabled { liveTouch.contacts = [] }
        }
    }

    private func updateLiveTouchGate() {
        let newValue = isVisible && isAppActive
        // Clear any lingering contacts on the way out so the canvas doesn't
        // paint a stale snapshot when the view becomes visible again.
        if !newValue && liveTouch.isPublishingEnabled {
            liveTouch.contacts = []
        }
        liveTouch.isPublishingEnabled = newValue
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test Area")
                .appFont(.headline)

            Text(
                String(
                    localized: "Draw with the pen. Two fingers pan the canvas; pinch zooms it.",
                    comment: "Description of the scratchpad drawing area"
                )
            )
            .appFont(.settingsLabel)
            .foregroundStyle(.secondary)

            ScratchpadCanvas(
                currentPressure: $currentPressure,
                zoomScale: $canvasZoom,
                clearID: clearID,
                resetViewportID: resetViewportID,
                tabletManager: tabletManager,
                undoManager: undoManager
            )
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.85), lineWidth: 1)
                }

            pressureRow

            visualizerRow
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var spec: WacomDeviceSpec? {
        productID.flatMap { WacomDeviceRegistry.spec(for: $0) }
    }

    private var pressureRow: some View {
        HStack(spacing: 10) {
            Text("Pressure")
                .appFont(.settingsLabel)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(pressureColor)
                        .frame(width: geo.size.width * currentPressure)
                        .animation(reduceMotion ? nil : .linear(duration: 0.05), value: currentPressure)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", currentPressure * 100))
                .appFont(.monospaced)
                .foregroundStyle(.secondary)
                .scaledFrame(width: 44, alignment: .trailing)

            Spacer()

            Button("Clear") {
                clearID += 1
            }
            .help("Erase all strokes from the test canvas")
            .controlSize(.small)

            Text("Canvas \(Int((canvasZoom * 100).rounded()))%")
                .appFont(.monospaced)
                .foregroundStyle(.secondary)

            Button("Reset View") {
                resetViewportID += 1
            }
            .help("Reset scratchpad pan and zoom")
            .controlSize(.small)
        }
    }

    /// Tilt and touch visualizers share one row. The touch surface preserves
    /// the detected tablet's coordinate aspect ratio instead of being forced
    /// into the tilt indicator's square frame.
    private var visualizerRow: some View {
        HStack(spacing: 24) {
            HStack(spacing: 10) {
                Text("Tilt")
                    .appFont(.settingsLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                TiltVisualizerCanvas(tabletManager: tabletManager)
                    .frame(width: 100, height: 100)
                    .help("Live tilt direction and magnitude from the active pen.")
            }

            if spec?.hasFingerTouch == true {
                HStack(spacing: 10) {
                    Text("Touch")
                        .appFont(.settingsLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    TouchVisualizer(
                        liveTouch: liveTouch,
                        maxContacts: spec?.maxTouchContacts ?? 10,
                        maxX: spec?.touchMaxX ?? 0,
                        maxY: spec?.touchMaxY ?? 0
                    )
                    .frame(width: 100 * touchSurfaceAspectRatio, height: 100)
                    .help("Live raw finger-touch positions across the active device's full touch surface.")
                }
            }
        }
    }

    /// The registry's touch coordinate maxima are the only per-device surface
    /// dimensions available to MockTab. Their ratio matches the reported
    /// touch area, including the PTH-660's rectangular sensor.
    private var touchSurfaceAspectRatio: CGFloat {
        let maxX = spec?.touchMaxX ?? 0
        let maxY = spec?.touchMaxY ?? 0
        guard maxX > 0, maxY > 0 else { return 1 }
        return CGFloat(maxX) / CGFloat(maxY)
    }

    private var pressureColor: Color {
        currentPressure < 0.5
            ? .accentColor
            : Color(hue: 0.05, saturation: 0.8, brightness: 0.85)
    }
}

// MARK: - Touch Visualizer wrapper

/// Isolation boundary for the live-touch stream: observes the publisher so
/// each ~30 Hz contact frame re-evaluates only this wrapper (and redraws the
/// Equatable-gated canvas when contacts actually changed) instead of the
/// whole Scratchpad pane.
private struct TouchVisualizer: View {
    @ObservedObject var liveTouch: LiveTouchPublisher
    let maxContacts: Int
    let maxX: Int
    let maxY: Int

    var body: some View {
        TouchContactsCanvas(
            contacts: liveTouch.contacts,
            maxContacts: maxContacts,
            maxX: maxX,
            maxY: maxY
        )
        .accessibilityLabel("Live touch surface showing \(liveTouch.contacts.count) detected contact\(liveTouch.contacts.count == 1 ? "" : "s")")
    }
}

// MARK: - Tilt Visualizer Canvas

/// Top-down disc that shows the active pen's live tilt as a dot offset from
/// center. Concentric reference rings give a magnitude scale; values are the
/// raw `tiltX`/`tiltY` from `TabletPoint` (each clamped to ±1). When the pen
/// leaves proximity the dot snaps back to center so the disc does not flicker
/// each time the user rolls the pen off the surface.
///
/// Performance: `livePoint` is not `@Published` (see `DeviceContext.livePoint`),
/// so this wrapper subscribes to `livePointPublisher` directly via `onReceive`
/// instead of relying on tabletManager's general objectWillChange cascade —
/// that keeps this ~16 Hz-when-frontmost redraw scoped to just this small
/// disc instead of also firing on every other view that merely observes
/// `tabletManager`. The inner `TiltDisc` is `Equatable` and keyed on a
/// quantized (tiltX, tiltY) pair, so SwiftUI skips body evaluation and the
/// Canvas redraw whenever tilt rounds to the same display position — sensor
/// noise and unrelated X/Y movement are filtered out for free.
struct TiltVisualizerCanvas: View {
    @ObservedObject var tabletManager: TabletManager
    /// Incremented by the `livePointPublisher` subscription below. It MUST be
    /// read in `body` (see the `let _` line) to register as a dependency —
    /// a `@State` write to a value the body never reads does not invalidate
    /// the view, so without the read the disc only refreshed when some *other*
    /// state (tip pressure) re-ran the parent body, i.e. only on fresh
    /// surface contact, never during pure hover. Matches InfoView's pattern.
    @State private var livePointTick = 0

    var body: some View {
        // Establishes livePointTick as a read dependency of this body so each
        // livePoint publish forces a re-evaluation.
        let _ = livePointTick
        // Quantize to 0.01 (sub-pixel on a 100-pt disc) so micro-jitter and
        // changes that wouldn't move the dot don't trigger redraws.
        let raw = tabletManager.activeContext?.livePoint
        let inProximity = raw?.inProximity == true
        let tx: Double = inProximity ? quantize(raw!.tiltX) : 0.0
        let ty: Double = inProximity ? quantize(raw!.tiltY) : 0.0
        return TiltDisc(tiltX: tx, tiltY: ty).equatable()
            .onReceive(
                tabletManager.activeContext?.livePointPublisher.eraseToAnyPublisher()
                    ?? Empty().eraseToAnyPublisher()
            ) { _ in livePointTick &+= 1 }
    }

    private func quantize(_ value: Double) -> Double {
        (max(-1.0, min(1.0, value)) * 100).rounded() / 100
    }
}

private struct TiltDisc: View, Equatable {
    let tiltX: Double
    let tiltY: Double

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let radius = min(size.width, size.height) * 0.5 - 6
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            Canvas { ctx, _ in
                drawReference(ctx: ctx, center: center, radius: radius)
                drawDot(ctx: ctx, center: center, radius: radius)
            }
        }
    }

    private func drawReference(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - radius, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - radius))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        ctx.stroke(cross, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)

        for fraction in [0.25, 0.5, 0.75] {
            let r = radius * fraction
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(.secondary.opacity(0.2)), lineWidth: 0.5)
        }

        let outer = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2)
        ctx.stroke(Path(ellipseIn: outer), with: .color(.secondary.opacity(0.45)), lineWidth: 1)
    }

    private func drawDot(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var tx = tiltX
        var ty = tiltY
        let magnitude = sqrt(tx * tx + ty * ty)
        if magnitude > 1.0 {
            tx /= magnitude
            ty /= magnitude
        }
        let dotX = center.x + radius * tx
        let dotY = center.y + radius * ty

        let r: CGFloat = 4
        let rect = CGRect(x: dotX - r, y: dotY - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(.accentColor))
        ctx.stroke(
            Path(ellipseIn: rect),
            with: .color(.white.opacity(0.9)), lineWidth: 1)
    }
}

// MARK: - Touch contacts visualizer

/// Top-down rectangle showing the raw finger-contact positions as their real
/// touch-surface locations. The canvas preserves the detected sensor ratio;
/// it never rescales a pair of contacts around their own bounding box.
/// Contacts fade out over ~0.3 s after they lift (lift = empty contacts array).
private struct TouchContactsCanvas: View, Equatable {
    let contacts: [TouchContact]
    let maxContacts: Int
    let maxX: Int
    let maxY: Int

    static func == (lhs: TouchContactsCanvas, rhs: TouchContactsCanvas) -> Bool {
        lhs.contacts == rhs.contacts
            && lhs.maxContacts == rhs.maxContacts
            && lhs.maxX == rhs.maxX
            && lhs.maxY == rhs.maxY
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawBorder(ctx: ctx, size: size)
                drawContacts(ctx: ctx, size: size)
            }
        }
    }

    private func drawBorder(ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        ctx.stroke(
            Path(roundedRect: rect, cornerRadius: 3),
            with: .color(.secondary.opacity(0.3)), lineWidth: 1)
    }

    private func drawContacts(ctx: GraphicsContext, size: CGSize) {
        guard !contacts.isEmpty else { return }

        let r: CGFloat = 6
        let pad: CGFloat = r + 4
        let rawMaxX = CGFloat(Swift.max(maxX, 1))
        let rawMaxY = CGFloat(Swift.max(maxY, 1))

        for contact in contacts {
            let nx = Swift.min(1, Swift.max(0, CGFloat(contact.x) / rawMaxX))
            let ny = Swift.min(1, Swift.max(0, CGFloat(contact.y) / rawMaxY))

            let cx = pad + nx * (size.width  - 2 * pad)
            let cy = pad + ny * (size.height - 2 * pad)
            let dot = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            ctx.fill(Path(ellipseIn: dot), with: .color(.accentColor.opacity(0.8)))
            ctx.stroke(Path(ellipseIn: dot), with: .color(.white.opacity(0.9)), lineWidth: 1)

            // Label the hardware contact id, not this frame's array index, so
            // a lifted/reordered finger is obvious while diagnosing gestures.
            ctx.draw(
                Text("\(contact.id)")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white),
                at: CGPoint(x: cx, y: cy),
                anchor: .center)
        }
    }
}

// MARK: - NSViewRepresentable bridge

private struct ScratchpadCanvas: NSViewRepresentable {
    @Binding var currentPressure: Double
    @Binding var zoomScale: Double
    let clearID: Int
    let resetViewportID: Int
    let tabletManager: TabletManager
    let undoManager: UndoManager?

    func makeNSView(context: Context) -> ScratchpadNSView {
        let view = ScratchpadNSView()
        view.onPressureChange = { pressure in
            currentPressure = pressure
        }
        view.onZoomChange = { zoomScale = $0 }
        view.tabletManager = tabletManager
        view.injectedUndoManager = undoManager
        return view
    }

    func updateNSView(_ nsView: ScratchpadNSView, context: Context) {
        nsView.tabletManager = tabletManager
        nsView.injectedUndoManager = undoManager
        nsView.onZoomChange = { zoomScale = $0 }
        if clearID != context.coordinator.lastClearID {
            nsView.clear()
            context.coordinator.lastClearID = clearID
        }
        if resetViewportID != context.coordinator.lastResetViewportID {
            nsView.resetViewport()
            context.coordinator.lastResetViewportID = resetViewportID
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(clearID: clearID, resetViewportID: resetViewportID)
    }

    final class Coordinator {
        var lastClearID: Int
        var lastResetViewportID: Int

        init(clearID: Int, resetViewportID: Int) {
            self.lastClearID = clearID
            self.lastResetViewportID = resetViewportID
        }
    }
}

// MARK: - NSView drawing canvas

final class ScratchpadNSView: NSView {
    var onPressureChange: ((Double) -> Void)?
    var onZoomChange: ((Double) -> Void)?
    weak var tabletManager: TabletManager?
    var injectedUndoManager: UndoManager?

    override var undoManager: UndoManager? { injectedUndoManager ?? super.undoManager }

    private struct Stroke {
        var points: [(NSPoint, CGFloat)]
        var isEraser: Bool
    }

    private var strokes: [Stroke] = []
    private var currentStroke: Stroke?
    private var isErasingGesture = false

    /// Cached rendering of all committed strokes. Rebuilt whenever the stroke
    /// list changes or the view resizes. Lets draw(_:) composite a single image
    /// blit + the live stroke rather than re-rendering every segment every frame.
    private var strokeCache: NSImage?

    /// Cumulative canvas-to-view transform. Strokes remain in unscaled canvas
    /// coordinates, so touch pan and pinch never alter their geometry.
    ///
    /// Strokes are stored in canvas space (stable coordinates independent of
    /// view size). On each resize, `contentOffset.y` is adjusted by the height
    /// delta so that content stays anchored to the top-left corner: growing the
    /// window reveals space at the bottom/right; shrinking clips there first.
    ///
    /// Drawing applies this offset as a transform; mouse events subtract it
    /// before coordinates are stored.
    private var contentOffset: CGPoint = .zero
    private var canvasScale: CGFloat = 1
    private static let minimumCanvasScale: CGFloat = 0.25
    private static let maximumCanvasScale: CGFloat = 4.0
    private static let zoomSensitivity: CGFloat = 0.006

    /// Gesture-level diagnostics: aggregate per sequence instead of writing a
    /// log line for every 60–100 Hz scroll event.
    private var panLogActive = false
    private var panLogEvents = 0
    private var panLogTotalX: CGFloat = 0
    private var panLogTotalY: CGFloat = 0
    private var panLogEndTimer: Timer?
    private var zoomLogActive = false
    private var zoomLogEvents = 0
    private var zoomLogTotalDelta: CGFloat = 0
    private var zoomLogEndTimer: Timer?

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    // Ring cursor: white halo + black stroke for visibility on any background color.
    private static let ringCursor: NSCursor = {
        let size: CGFloat = 20
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let center = NSPoint(x: size / 2, y: size / 2)
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: 7, startAngle: 0, endAngle: 360)
            NSColor.white.setStroke()
            path.lineWidth = 3
            path.stroke()
            NSColor.black.setStroke()
            path.lineWidth = 1.5
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: size / 2, y: size / 2))
    }()

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: Self.ringCursor)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        panLogEndTimer?.invalidate()
        zoomLogEndTimer?.invalidate()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        NSEvent.isMouseCoalescingEnabled = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        strokeCache = nil
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = bounds.size
        super.setFrameSize(newSize)
        // Skip the initial layout pass (oldSize is zero before the first frame
        // is set) so the offset doesn't pick up the full initial height.
        if oldSize.height > 0 {
            contentOffset.y += newSize.height - oldSize.height
        }
        strokeCache = nil
        needsDisplay = true
    }

    // MARK: - Coordinate helpers

    /// Converts a point in view space to canvas space (stable across resizes).
    private func canvasPoint(_ viewPt: NSPoint) -> NSPoint {
        NSPoint(
            x: (viewPt.x - contentOffset.x) / canvasScale,
            y: (viewPt.y - contentOffset.y) / canvasScale)
    }

    /// Converts a point in canvas space back to view space (for dirty-rect math).
    private func viewPoint(_ canvasPt: NSPoint) -> NSPoint {
        NSPoint(
            x: canvasPt.x * canvasScale + contentOffset.x,
            y: canvasPt.y * canvasScale + contentOffset.y)
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        let pt = canvasPoint(convert(event.locationInWindow, from: nil))
        let activeContext = tabletManager?.activeContext
        let isEraser = tabletManager?.injector?.activeToolIsEraser == true
            || activeContext?.activeToolID?.hasPrefix("eraser") == true
            || event.pointingDeviceType == .eraser
            || activeContext?.livePoint?.eraser == true
            || activeContext?.liveButtons.eraserDown == true
        if isEraser {
            currentStroke = nil
            isErasingGesture = true
            undoManager?.beginUndoGrouping()
            eraseStrokes(crossing: pt)
        } else {
            isErasingGesture = false
            currentStroke = Stroke(points: [(pt, CGFloat(event.pressure))], isEraser: false)
        }
        onPressureChange?(Double(event.pressure))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let viewPt = convert(event.locationInWindow, from: nil)
        let pt = canvasPoint(viewPt)
        if isErasingGesture {
            eraseStrokes(crossing: pt)
            onPressureChange?(Double(event.pressure))
            return
        }
        guard let previousCanvas = currentStroke?.points.last?.0 else { return }
        currentStroke?.points.append((pt, CGFloat(event.pressure)))
        onPressureChange?(Double(event.pressure))
        // Dirty rect is in view space; convert the previous canvas point back.
        let previousView = viewPoint(previousCanvas)
        let pad: CGFloat = Swift.max(2, CGFloat(event.pressure) * 20 * canvasScale)
        let minX = Swift.min(previousView.x, viewPt.x) - pad
        let maxX = Swift.max(previousView.x, viewPt.x) + pad
        let minY = Swift.min(previousView.y, viewPt.y) - pad
        let maxY = Swift.max(previousView.y, viewPt.y) + pad
        setNeedsDisplay(NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }

    override func mouseUp(with event: NSEvent) {
        if isErasingGesture {
            isErasingGesture = false
            undoManager?.setActionName(
                NSLocalizedString("Erase", comment: "Undo name for eraser stroke")
            )
            undoManager?.endUndoGrouping()
        } else if let finished = currentStroke, !finished.points.isEmpty {
            currentStroke = nil
            commitStroke(finished)
        } else {
            currentStroke = nil
        }

        onPressureChange?(0)
        needsDisplay = true
    }

    /// MockTab injects two-finger pan as a continuous pixel-wheel event and
    /// pinch as that event with Control held. Treat both as canvas navigation
    /// so Scratchpad directly verifies the tablet's touch gestures.
    override func scrollWheel(with event: NSEvent) {
        let viewPt = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.control) {
            zoom(around: viewPt, delta: event.scrollingDeltaY)
        } else {
            pan(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        }
    }

    private func pan(dx: CGFloat, dy: CGFloat) {
        guard dx != 0 || dy != 0 else { return }
        recordPan(dx: dx, dy: dy)
        // TouchStateTracker already resolves horizontal motion into a
        // content-following delta. Scratchpad's unflipped AppKit canvas has
        // the opposite vertical axis, so only Y needs inversion.
        contentOffset.x += dx
        contentOffset.y -= dy
        strokeCache = nil
        needsDisplay = true
    }

    private func zoom(around viewPt: NSPoint, delta: CGFloat) {
        guard delta != 0 else { return }
        let anchor = canvasPoint(viewPt)
        let factor = exp(delta * Self.zoomSensitivity)
        let newScale = Swift.max(
            Self.minimumCanvasScale,
            Swift.min(Self.maximumCanvasScale, canvasScale * factor))
        guard newScale != canvasScale else { return }
        recordZoom(delta: delta)
        canvasScale = newScale
        contentOffset = CGPoint(
            x: viewPt.x - anchor.x * canvasScale,
            y: viewPt.y - anchor.y * canvasScale)
        strokeCache = nil
        onZoomChange?(Double(canvasScale))
        needsDisplay = true
    }

    private func recordPan(dx: CGFloat, dy: CGFloat) {
        if !panLogActive {
            panLogActive = true
            panLogEvents = 0
            panLogTotalX = 0
            panLogTotalY = 0
            scratchpadLog.notice("pan begin scale=\(self.canvasScale)")
        }
        panLogEvents += 1
        panLogTotalX += dx
        panLogTotalY += dy
        panLogEndTimer?.invalidate()
        panLogEndTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: false) { [weak self] _ in
            self?.finishPanLog(reason: "idle")
        }
    }

    private func finishPanLog(reason: String) {
        panLogEndTimer?.invalidate()
        panLogEndTimer = nil
        guard panLogActive else { return }
        scratchpadLog.notice(
            "pan end reason=\(reason, privacy: .public) events=\(self.panLogEvents) wheelDx=\(self.panLogTotalX) wheelDy=\(self.panLogTotalY) canvasDx=\(self.panLogTotalX) canvasDy=\(-self.panLogTotalY)")
        panLogActive = false
    }

    private func recordZoom(delta: CGFloat) {
        if !zoomLogActive {
            zoomLogActive = true
            zoomLogEvents = 0
            zoomLogTotalDelta = 0
            scratchpadLog.notice("zoom begin scale=\(self.canvasScale)")
        }
        zoomLogEvents += 1
        zoomLogTotalDelta += delta
        zoomLogEndTimer?.invalidate()
        zoomLogEndTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: false) { [weak self] _ in
            self?.finishZoomLog(reason: "idle")
        }
    }

    private func finishZoomLog(reason: String) {
        zoomLogEndTimer?.invalidate()
        zoomLogEndTimer = nil
        guard zoomLogActive else { return }
        scratchpadLog.notice(
            "zoom end reason=\(reason, privacy: .public) events=\(self.zoomLogEvents) delta=\(self.zoomLogTotalDelta) scale=\(self.canvasScale)")
        zoomLogActive = false
    }

    func resetViewport() {
        guard contentOffset != .zero || canvasScale != 1 else { return }
        contentOffset = .zero
        canvasScale = 1
        strokeCache = nil
        onZoomChange?(1)
        needsDisplay = true
    }

    func clear() {
        let previous = strokes
        currentStroke = nil
        guard !previous.isEmpty else {
            onPressureChange?(0)
            needsDisplay = true
            return
        }
        strokes.removeAll()
        strokeCache = nil
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreStrokes(previous)
        }
        undoManager?.setActionName(
            NSLocalizedString("Clear Canvas", comment: "Undo name for clearing the scratchpad")
        )
        onPressureChange?(0)
        needsDisplay = true
    }

    // MARK: - Undo helpers

    private func commitStroke(_ stroke: Stroke) {
        let index = strokes.count
        strokes.append(stroke)
        strokeCache = nil
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeStroke(at: index)
        }
        undoManager?.setActionName(
            stroke.isEraser
                ? NSLocalizedString("Erase", comment: "Undo name for eraser stroke")
                : NSLocalizedString("Draw", comment: "Undo name for ink stroke")
        )
        needsDisplay = true
    }

    private func removeStroke(at index: Int) {
        guard strokes.indices.contains(index) else { return }
        let removed = strokes.remove(at: index)
        strokeCache = nil
        undoManager?.registerUndo(withTarget: self) { target in
            target.insertStroke(removed, at: index)
        }
        needsDisplay = true
    }

    private func insertStroke(_ stroke: Stroke, at index: Int) {
        let clamped = min(max(index, 0), strokes.count)
        strokes.insert(stroke, at: clamped)
        strokeCache = nil
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeStroke(at: clamped)
        }
        needsDisplay = true
    }

    private func eraseStrokes(crossing point: NSPoint) {
        let radius: CGFloat = 12
        var removed = false
        var index = strokes.count - 1
        while index >= 0 {
            if strokeHitTest(strokes[index], near: point, radius: radius) {
                removeStroke(at: index)
                removed = true
            }
            index -= 1
        }
        if removed { needsDisplay = true }
    }

    private func strokeHitTest(_ stroke: Stroke, near point: NSPoint, radius: CGFloat) -> Bool {
        let r2 = radius * radius
        let pts = stroke.points
        if pts.count == 1 {
            let dx = pts[0].0.x - point.x
            let dy = pts[0].0.y - point.y
            return dx * dx + dy * dy <= r2
        }
        for index in 1 ..< pts.count {
            if segmentDistanceSquared(point, pts[index - 1].0, pts[index].0) <= r2 {
                return true
            }
        }
        return false
    }

    private func segmentDistanceSquared(_ p: NSPoint, _ a: NSPoint, _ b: NSPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 {
            let ex = p.x - a.x
            let ey = p.y - a.y
            return ex * ex + ey * ey
        }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = Swift.max(0, Swift.min(1, t))
        let cx = a.x + t * dx
        let cy = a.y + t * dy
        let ex = p.x - cx
        let ey = p.y - cy
        return ex * ex + ey * ey
    }

    private func restoreStrokes(_ previous: [Stroke]) {
        let current = strokes
        strokes = previous
        strokeCache = nil
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreStrokes(current)
        }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        drawDotGrid(in: dirtyRect)

        // Composite the cached image of all committed strokes (a single blit),
        // then draw only the live stroke on top. This keeps per-frame cost
        // constant with respect to stroke history.
        let cache = strokeCache ?? buildStrokeCache()
        cache.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)

        if let currentStroke {
            NSGraphicsContext.saveGraphicsState()
            applyContentOffset()
            drawStroke(currentStroke)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// Pushes the canvas-to-view transform onto the current graphics context.
    private func applyContentOffset() {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.translateBy(x: contentOffset.x, y: contentOffset.y)
        context.scaleBy(x: canvasScale, y: canvasScale)
    }

    /// Renders all committed strokes into an NSImage the same size as the view.
    /// Called at most once per stroke-list mutation; result is reused every frame.
    private func buildStrokeCache() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        applyContentOffset()
        for stroke in strokes {
            drawStroke(stroke)
        }
        image.unlockFocus()
        strokeCache = image
        return image
    }

    private func drawDotGrid(in dirtyRect: NSRect) {
        let gridColor = NSColor.gridColor.withAlphaComponent(0.20)
        gridColor.setFill()

        let spacing: CGFloat = 16
        let radius: CGFloat = 0.75

        // Snap to the nearest grid line on or before the dirty rect, then
        // iterate only within it. A single batched path avoids allocating one
        // NSBezierPath per dot on every partial repaint.
        let startX = ceil(max(spacing, dirtyRect.minX - radius) / spacing) * spacing
        let startY = ceil(max(spacing, dirtyRect.minY - radius) / spacing) * spacing

        let path = NSBezierPath()
        var x = startX
        while x < bounds.width && x <= dirtyRect.maxX + radius {
            var y = startY
            while y < bounds.height && y <= dirtyRect.maxY + radius {
                path.appendOval(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                y += spacing
            }
            x += spacing
        }
        path.fill()
    }

    private func drawStroke(_ stroke: Stroke) {
        let points = stroke.points
        let inkColor: NSColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? .white : .black
        }
        inkColor.setStroke()
        inkColor.setFill()

        guard points.count >= 2 else {
            if let (point, pressure) = points.first {
                let radius = Swift.max(1.0, pressure * 10)
                let dotRect = CGRect(
                    x: point.x - radius / 2,
                    y: point.y - radius / 2,
                    width: radius,
                    height: radius
                )
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return
        }

        guard points.count >= 3 else {
            // Only two raw points — straight segment, no smoothing needed.
            let (p0, pressure0) = points[0]
            let (p1, pressure1) = points[1]
            let seg = NSBezierPath()
            seg.lineWidth = Swift.max(0.5, ((pressure0 + pressure1) / 2) * 20.0)
            seg.lineCapStyle = .round
            seg.move(to: p0)
            seg.line(to: p1)
            seg.stroke()
            return
        }

        // Midpoint bezier smoothing: each segment spans from
        // midpoint(p[i-1], p[i]) to midpoint(p[i], p[i+1]), using p[i] as a
        // quadratic control point (converted to cubic for NSBezierPath).
        // The first and last raw endpoints are preserved exactly.
        // Stored sample data is unchanged — smoothing is render-only.

        // First segment: raw start → midpoint(p[0], p[1]), straight.
        let firstMid = NSPoint(
            x: (points[0].0.x + points[1].0.x) / 2,
            y: (points[0].0.y + points[1].0.y) / 2)
        do {
            let seg = NSBezierPath()
            seg.lineWidth = Swift.max(0.5, ((points[0].1 + points[1].1) / 2) * 20.0)
            seg.lineCapStyle = .round
            seg.move(to: points[0].0)
            seg.line(to: firstMid)
            seg.stroke()
        }

        // Interior segments: smoothed arcs between consecutive midpoints.
        for i in 1 ..< points.count - 1 {
            let (p0, _) = points[i - 1]
            let (ctrl, pressure) = points[i]
            let (p2, _) = points[i + 1]

            let segStart = NSPoint(x: (p0.x + ctrl.x) / 2, y: (p0.y + ctrl.y) / 2)
            let segEnd   = NSPoint(x: (ctrl.x + p2.x) / 2, y: (ctrl.y + p2.y) / 2)

            // Quadratic (segStart, ctrl, segEnd) → cubic control points.
            let cp1 = NSPoint(x: (segStart.x + 2 * ctrl.x) / 3, y: (segStart.y + 2 * ctrl.y) / 3)
            let cp2 = NSPoint(x: (2 * ctrl.x + segEnd.x) / 3,   y: (2 * ctrl.y + segEnd.y) / 3)

            let seg = NSBezierPath()
            seg.lineWidth = Swift.max(0.5, pressure * 20.0)
            seg.lineCapStyle = .round
            seg.lineJoinStyle = .round
            seg.move(to: segStart)
            seg.curve(to: segEnd, controlPoint1: cp1, controlPoint2: cp2)
            seg.stroke()
        }

        // Last segment: midpoint(p[n-2], p[n-1]) → raw end, straight.
        let n = points.count
        let lastMid = NSPoint(
            x: (points[n - 2].0.x + points[n - 1].0.x) / 2,
            y: (points[n - 2].0.y + points[n - 1].0.y) / 2)
        do {
            let seg = NSBezierPath()
            seg.lineWidth = Swift.max(0.5, ((points[n - 2].1 + points[n - 1].1) / 2) * 20.0)
            seg.lineCapStyle = .round
            seg.move(to: lastMid)
            seg.line(to: points[n - 1].0)
            seg.stroke()
        }
    }
}
