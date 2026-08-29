import Foundation

struct Tablet {
    var id: UUID = UUID()
    var productID: Int
}

let numTablets = 1000
let tablets = (0..<numTablets).map { Tablet(productID: $0) }
let connectedProductIDs = Array(0..<100)

func testArrayContains() -> TimeInterval {
    let start = Date()
    for _ in 0..<10000 {
        var count = 0
        for tablet in tablets {
            if connectedProductIDs.contains(tablet.productID) {
                count += 1
            }
        }
    }
    return Date().timeIntervalSince(start)
}

func testSetContains() -> TimeInterval {
    let start = Date()
    for _ in 0..<10000 {
        var count = 0
        let connectedSet = Set(connectedProductIDs)
        for tablet in tablets {
            if connectedSet.contains(tablet.productID) {
                count += 1
            }
        }
    }
    return Date().timeIntervalSince(start)
}

let baseline = testArrayContains()
let optimized = testSetContains()

print(String(format: "Baseline (10k iterations): %.4f seconds", baseline))
print(String(format: "Optimized (10k iterations): %.4f seconds", optimized))
let improvement = ((baseline - optimized) / baseline) * 100
print(String(format: "Improvement: %.2f%%", improvement))
