import Foundation

// Assuming we can mock or just time the array vs set approach
let knownTabletsCount = 500
let connectedTablets = [100, 200, 300, 400]

let startArray = CFAbsoluteTimeGetCurrent()
for i in 0..<10000 {
    for j in 0..<knownTabletsCount {
        let connected = connectedTablets.contains(j)
    }
}
let timeArray = CFAbsoluteTimeGetCurrent() - startArray

let startSet = CFAbsoluteTimeGetCurrent()
for i in 0..<10000 {
    let connectedSet = Set(connectedTablets)
    for j in 0..<knownTabletsCount {
        let connected = connectedSet.contains(j)
    }
}
let timeSet = CFAbsoluteTimeGetCurrent() - startSet

print("Array time: \(timeArray)")
print("Set time:   \(timeSet)")
