import Foundation
import XCTest
@testable import MockTab

class DeviceInstanceKeyTests: XCTestCase {

    func testDeviceInstanceKeyHashable() {
        let key1 = DeviceInstanceKey(productID: 1234, vendorID: 5678)
        let key2 = DeviceInstanceKey(productID: 1234, vendorID: 5678)
        let key3 = DeviceInstanceKey(productID: 1234, vendorID: 9012)
        let key4 = DeviceInstanceKey(productID: 9012, vendorID: 5678)

        XCTAssertEqual(key1, key2, "Keys with same properties should be equal")
        XCTAssertEqual(key1.hashValue, key2.hashValue, "Keys with same properties should have same hash value")

        XCTAssertNotEqual(key1, key3, "Keys with different vendorIDs should not be equal")
        XCTAssertNotEqual(key1.hashValue, key3.hashValue, "Keys with different vendorIDs should have different hash values")

        XCTAssertNotEqual(key1, key4, "Keys with different productIDs should not be equal")
        XCTAssertNotEqual(key1.hashValue, key4.hashValue, "Keys with different productIDs should have different hash values")
    }

    func testDeviceInstanceKeyCodable() throws {
        let originalKey = DeviceInstanceKey(productID: 1234, vendorID: 5678)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(originalKey)
        let decodedKey = try decoder.decode(DeviceInstanceKey.self, from: encodedData)

        XCTAssertEqual(originalKey, decodedKey, "Decoded key should match the original encoded key")
        XCTAssertEqual(originalKey.productID, decodedKey.productID)
        XCTAssertEqual(originalKey.vendorID, decodedKey.vendorID)
    }
}
