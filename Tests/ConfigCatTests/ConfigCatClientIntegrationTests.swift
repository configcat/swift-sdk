import XCTest
@testable import ConfigCat

class ConfigCatClientIntegrationTests: XCTestCase {
    func testGetAllKeys() {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let expectation = expectation(description: "wait for all keys")
        client.getAllKeys { keys in
            XCTAssertEqual(16, keys.count)
            XCTAssertTrue(keys.contains("stringDefaultCat"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetAllValues() {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let expectation = expectation(description: "wait for all values")
        client.getAllValues { allValues in
            XCTAssertEqual(16, allValues.count)
            XCTAssertEqual("Cat", allValues["stringDefaultCat"] as! String)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
}
