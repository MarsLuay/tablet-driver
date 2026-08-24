import Foundation

struct DummyModel: Codable {
    var id: UUID = UUID()
    var name: String = "Test Model"
    var value: Int = 42
}

func testBaseline() -> TimeInterval {
    let rawStr = try! String(data: JSONEncoder().encode([DummyModel(), DummyModel(), DummyModel()]), encoding: .utf8)!

    let start = Date()
    for _ in 0..<10000 {
        if let data = rawStr.data(using: .utf8),
           let arr = try? JSONDecoder().decode([DummyModel].self, from: data) {
            var r = arr
            while r.count < 16 { r.append(DummyModel()) }
            _ = Array(r.prefix(16))
        }
    }
    return Date().timeIntervalSince(start)
}

func testOptimized() -> TimeInterval {
    let rawStr = try! String(data: JSONEncoder().encode([DummyModel(), DummyModel(), DummyModel()]), encoding: .utf8)!

    let start = Date()
    let decoder = JSONDecoder()
    for _ in 0..<10000 {
        if let data = rawStr.data(using: .utf8),
           let arr = try? decoder.decode([DummyModel].self, from: data) {
            var r = arr
            while r.count < 16 { r.append(DummyModel()) }
            _ = Array(r.prefix(16))
        }
    }
    return Date().timeIntervalSince(start)
}

let baseline = testBaseline()
let optimized = testOptimized()

print(String(format: "Baseline (10k iterations): %.4f seconds", baseline))
print(String(format: "Optimized (10k iterations): %.4f seconds", optimized))
let improvement = ((baseline - optimized) / baseline) * 100
print(String(format: "Improvement: %.2f%%", improvement))
