import Foundation

func formattedDateOld(_ iso: String) -> String {
    let parser = ISO8601DateFormatter()
    guard let date = parser.date(from: iso) else { return iso }
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt.string(from: date)
}

let isoParser = ISO8601DateFormatter()
let displayFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
}()

func formattedDateNew(_ iso: String) -> String {
    guard let date = isoParser.date(from: iso) else { return iso }
    return displayFormatter.string(from: date)
}

let dateStr = "2023-10-25T14:30:00Z"

let startOld = Date()
for _ in 0..<10000 {
    _ = formattedDateOld(dateStr)
}
let timeOld = Date().timeIntervalSince(startOld)

let startNew = Date()
for _ in 0..<10000 {
    _ = formattedDateNew(dateStr)
}
let timeNew = Date().timeIntervalSince(startNew)

print(String(format: "Baseline (10k iterations): %.4f seconds", timeOld))
print(String(format: "Optimized (10k iterations): %.4f seconds", timeNew))
let improvement = ((timeOld - timeNew) / timeOld) * 100
print(String(format: "Improvement: %.2f%%", improvement))
