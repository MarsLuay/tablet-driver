import Foundation

// We will compile this against DeviceInstanceKey.swift
@main
enum Benchmark {
    static func main() {
        let ud = UserDefaults(suiteName: "benchmark")!
        ud.removePersistentDomain(forName: "benchmark")
        var claims = DeviceInstanceClaims(ud: ud)

        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<10000 {
            let key = DeviceInstanceKey(productID: i % 1000, instance: "instance-\(i)")
            _ = claims.settingsPrefix(for: key)
        }
        let end = CFAbsoluteTimeGetCurrent()
        print("Elapsed time: \(end - start) seconds")
    }
}
