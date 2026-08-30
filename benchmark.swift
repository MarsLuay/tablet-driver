import Foundation

struct ToolIdentity {
    var serial: UInt32
    var toolCode: UInt16
    var isEraser: Bool
    var isMouse: Bool
}

struct TabletManager {
    static func deviceName(forProductID: Int, vendorID: Int, productString: String?) -> String {
        return "StubDevice"
    }
}

struct WacomDeviceRegistry {
    struct Spec { var family: String }
    static func spec(for productID: Int) -> Spec? {
        return Spec(family: "universal")
    }
}

struct WacomToolCatalog {
    struct Capabilities { var isSupported: Bool }
    static func name(forToolCode: UInt16) -> String { return "StubPen" }
    static func capabilities(forToolCode: UInt16, family: String) -> Capabilities {
        return Capabilities(isSupported: true)
    }
}

@MainActor
func runBenchmark() {
    let registry = DeviceRegistry.shared

    // Warm up
    for i in 1...1000 {
        registry.recordHardwareSerial(UInt32(i), forDevice: i)
    }

    let iterations = 50000
    let start = Date()
    for i in 1...iterations {
        _ = registry.canonicalProductID(forHardwareSerial: UInt32(i))
    }
    let end = Date()
    let elapsed = end.timeIntervalSince(start)
    print("Elapsed time: \(elapsed) seconds")
}
runBenchmark()
