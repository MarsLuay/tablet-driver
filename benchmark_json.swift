import Foundation

struct KnownTool: Codable {
    var id: String
    var nickname: String
}

let sampleTools = (0..<10).map { KnownTool(id: "tool\($0)", nickname: "Nickname \($0)") }
let sampleData = try! JSONEncoder().encode(sampleTools)
let loopCount = 10000

let startOld = Date()
for _ in 0..<loopCount {
    let _ = try? JSONDecoder().decode([KnownTool].self, from: sampleData)
    let _ = try? JSONEncoder().encode(sampleTools)
}
let timeOld = Date().timeIntervalSince(startOld)

let startNew = Date()
let decoder = JSONDecoder()
let encoder = JSONEncoder()
for _ in 0..<loopCount {
    let _ = try? decoder.decode([KnownTool].self, from: sampleData)
    let _ = try? encoder.encode(sampleTools)
}
let timeNew = Date().timeIntervalSince(startNew)

print(String(format: "Baseline (10k iterations): %.4f seconds", timeOld))
print(String(format: "Optimized (10k iterations): %.4f seconds", timeNew))
let improvement = ((timeOld - timeNew) / timeOld) * 100
print(String(format: "Improvement: %.2f%%", improvement))
