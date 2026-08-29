import Foundation

// Mock objects
class DeviceRegistry {
    static let shared = DeviceRegistry()
    struct Tablet {
        let productID: Int
        let instanceKey: String
    }
    var knownTablets: [Tablet] = []

    init() {
        for i in 0..<100_000 {
            knownTablets.append(Tablet(productID: i, instanceKey: "Key-\(i)"))
        }
    }
}

class TabletManager {
    static let shared = TabletManager()
    var connectedProductIDs: [Int] = []
    var activeContext: String? = nil

    init() {
        for i in 90_000..<90_100 {
            connectedProductIDs.append(i)
        }
    }
}

func activateBestDevice_original() {
    let tm = TabletManager.shared
    let registry = DeviceRegistry.shared

    let start = CFAbsoluteTimeGetCurrent()

    let key = tm.activeContext
        ?? registry.knownTablets.first(where: {
            tm.connectedProductIDs.contains($0.productID)
        })?.instanceKey
        ?? registry.knownTablets.first?.instanceKey

    let end = CFAbsoluteTimeGetCurrent()
    print("Original: \((end - start) * 1000) ms")
}

func activateBestDevice_optimized() {
    let tm = TabletManager.shared
    let registry = DeviceRegistry.shared

    let start = CFAbsoluteTimeGetCurrent()

    let connectedSet = Set(tm.connectedProductIDs)
    let key = tm.activeContext
        ?? registry.knownTablets.first(where: {
            connectedSet.contains($0.productID)
        })?.instanceKey
        ?? registry.knownTablets.first?.instanceKey

    let end = CFAbsoluteTimeGetCurrent()
    print("Optimized: \((end - start) * 1000) ms")
}

activateBestDevice_original()
activateBestDevice_optimized()
