import XCTest
@testable import ConfigCat

class SyncTests: XCTestCase {
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [{"o":1,"a":"Email","t":2,"c":"@example.com","v":true,"i":"9f21c24c"}] } } }"#
    let user = ConfigCatUser(identifier: "id", email: "test@example.com")

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
        MockHTTP.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
    }

    func testGetValue() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let value = client.getValueSync(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = client.getValueSync(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }

    func testGetVariationId() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let id = client.getVariationIdSync(for: "key1", defaultVariationId: "")
        XCTAssertEqual("fakeId1", id)
        let id2 = client.getVariationIdSync(for: "key2", defaultVariationId: "", user: user)
        XCTAssertEqual("9f21c24c", id2)
    }

    func testGetKeyValue() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let id = client.getKeyAndValueSync(for: "fakeId1")
        XCTAssertEqual(true, id?.value as? Bool)
        XCTAssertEqual("key1", id?.key)
    }

    func testGetAllKeys() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let keys = client.getAllKeysSync()
        XCTAssertEqual(2, keys.count)
    }

    func testGetAllValues() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let values = client.getAllValuesSync()
        XCTAssertEqual(2, values.count)
    }

    func testRefresh() {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.refreshSync()
        let value = client.getValueSync(for: "key2", defaultValue: true)
        XCTAssertFalse(value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }
}
