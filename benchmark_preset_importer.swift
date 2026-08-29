import Foundation

struct KnownTablet {
    let productID: Int
}

let knownTablets = (0..<1000).map { KnownTablet(productID: $0) }
let tabletsRaw = (500..<1500).map { ["productID": "0x\(String(format: "%04X", $0))"] }

let loopCount = 1000

let startOld = Date()
for _ in 0..<loopCount {
    for tabletDict in tabletsRaw {
        guard let pidStr = tabletDict["productID"],
              let pid = Int(pidStr.dropFirst(2), radix: 16) else { continue }

        let isKnown = knownTablets.contains { $0.productID == pid }
        _ = isKnown
    }
}
let timeOld = Date().timeIntervalSince(startOld)

let startNew = Date()
for _ in 0..<loopCount {
    let knownProductIDs = Set(knownTablets.map { $0.productID })
    for tabletDict in tabletsRaw {
        guard let pidStr = tabletDict["productID"],
              let pid = Int(pidStr.dropFirst(2), radix: 16) else { continue }

        let isKnown = knownProductIDs.contains(pid)
        _ = isKnown
    }
}
let timeNew = Date().timeIntervalSince(startNew)

print(String(format: "Baseline: %.4f seconds", timeOld))
print(String(format: "Optimized: %.4f seconds", timeNew))
let improvement = ((timeOld - timeNew) / timeOld) * 100
print(String(format: "Improvement: %.2f%%", improvement))
