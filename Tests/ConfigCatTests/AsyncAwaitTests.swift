import XCTest
@testable import ConfigCat

class AsyncAwaitTests: XCTestCase {
    #if compiler(>=5.5) && canImport(_Concurrency)
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [{"o":1,"a":"Email","t":2,"c":"@example.com","v":true,"i":"9f21c24c"}] } } }"#
    let user = ConfigCatUser(identifier: "id", email: "test@example.com")

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValue() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let value = await client.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = await client.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetVariationId() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let id = await client.getVariationId(for: "key1", defaultVariationId: "")
        XCTAssertEqual("fakeId1", id)
        let id2 = await client.getVariationId(for: "key2", defaultVariationId: "", user: user)
        XCTAssertEqual("9f21c24c", id2)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetKeyValue() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let id = await client.getKeyAndValue(for: "fakeId1")
        XCTAssertEqual(true, id?.value as? Bool)
        XCTAssertEqual("key1", id?.key)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllKeys() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let keys = await client.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValues() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let values = await client.getAllValues()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValueDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let values = await client.getAllValueDetails()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefresh() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        let result = await client.forceRefresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertTrue(result.success)
        XCTAssertFalse(value)
        XCTAssertEqual(1, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefreshWithoutResult() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        await client.forceRefresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertFalse(value)
        XCTAssertEqual(1, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let details = await client.getValueDetails(for: "key2", defaultValue: true)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertFalse(details.value)
        XCTAssertEqual(1, engine.requests.count)
    }
    #endif
}
