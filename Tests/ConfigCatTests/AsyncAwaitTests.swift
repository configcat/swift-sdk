import XCTest
@testable import ConfigCat

class AsyncAwaitTests: XCTestCase {
#if compiler(>=5.5) && canImport(_Concurrency)
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
        MockHTTP.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
    }

    @available(macOS 10.15, iOS 13, *)
    func testGetValue() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let value = await client.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
    }
    
    @available(macOS 10.15, iOS 13, *)
    func testGetVariationId() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let id = await client.getVariationId(for: "key1", defaultVariationId: "")
        XCTAssertEqual("fakeId1", id)
    }

    @available(macOS 10.15, iOS 13, *)
    func testGetKeyValue() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let id = await client.getKeyAndValue(for: "fakeId1")
        XCTAssertEqual(true, id?.value as? Bool)
        XCTAssertEqual("key1", id?.key)
    }

    @available(macOS 10.15, iOS 13, *)
    func testGetAllKeys() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let keys = await client.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }

    @available(macOS 10.15, iOS 13, *)
    func testGetAllValues() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let values = await client.getAllValues()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, *)
    func testRefresh() async {
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
        await client.refresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertFalse(value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }
#endif
}
