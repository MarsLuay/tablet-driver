import Foundation

// Original implementation
func buildDiagnosticTextOriginal() -> String {
    var lines: [String] = []

    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    lines += ["Generated : \(fmt.string(from: Date()))"]

    return lines.joined(separator: "\n")
}

// Optimized implementation
let sharedFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return fmt
}()

func buildDiagnosticTextOptimized() -> String {
    var lines: [String] = []

    lines += ["Generated : \(sharedFormatter.string(from: Date()))"]

    return lines.joined(separator: "\n")
}

let iterations = 10000

print("Benchmarking Original...")
let startOriginal = CFAbsoluteTimeGetCurrent()
for _ in 0..<iterations {
    _ = buildDiagnosticTextOriginal()
}
let timeOriginal = CFAbsoluteTimeGetCurrent() - startOriginal
print("Original time: \(timeOriginal) seconds")

print("Benchmarking Optimized...")
let startOptimized = CFAbsoluteTimeGetCurrent()
for _ in 0..<iterations {
    _ = buildDiagnosticTextOptimized()
}
let timeOptimized = CFAbsoluteTimeGetCurrent() - startOptimized
print("Optimized time: \(timeOptimized) seconds")

let improvement = (timeOriginal - timeOptimized) / timeOriginal * 100
print(String(format: "Improvement: %.2f%%", improvement))
