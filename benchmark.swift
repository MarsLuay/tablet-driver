import Foundation

func measure(name: String, _ block: () -> Void) {
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<10000 {
        block()
    }
    let end = CFAbsoluteTimeGetCurrent()
    print("\(name): \(String(format: "%.4f", end - start)) seconds")
}

func localFormatter() -> String {
    let iso = ISO8601DateFormatter()
    return iso.string(from: Date())
}

let staticISO = ISO8601DateFormatter()
func staticFormatter() -> String {
    return staticISO.string(from: Date())
}

measure(name: "Local Formatter", { _ = localFormatter() })
measure(name: "Static Formatter", { _ = staticFormatter() })
