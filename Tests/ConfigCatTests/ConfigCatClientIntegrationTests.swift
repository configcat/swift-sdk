import XCTest
@testable import ConfigCat

class ConfigCatClientIntegrationTests: XCTestCase {
    func testGetAllKeys() {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let keys = client.getAllKeys()
        XCTAssertEqual(16, keys.count)
        XCTAssertTrue(keys.contains("stringDefaultCat"))
    }

    func testGetAllValues() {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let allValues = client.getAllValues()
        XCTAssertEqual(16, allValues.count)
        XCTAssertEqual("Cat", allValues["stringDefaultCat"] as! String)
    }

    func testGetAllValuesAsync() throws {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let allValuesResult = AsyncResult<[String: Any]>()
        client.getAllValuesAsync() { (result, error) in
            XCTAssertNil(error)
            allValuesResult.complete(result: result)
        }
        let allValues = try allValuesResult.get()
        XCTAssertEqual(16, allValues.count)
        XCTAssertEqual("Cat", allValues["stringDefaultCat"] as! String)
    }
}
