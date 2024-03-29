import XCTest
@testable import ConfigCat

class AsyncAwaitTests: XCTestCase {
    #if compiler(>=5.5) && canImport(_Concurrency)
    let testJsonMultiple = #"{"f":{"key1":{"t":0,"v":{"b":true},"i":"fakeId1"},"key2":{"t":0,"r":[{"c":[{"u":{"a":"Email","c":2,"l":["@example.com"]}}],"s":{"v":{"b":true},"i":"9f21c24c"}}],"v":{"b":false},"i":"fakeId2"}}}"#
    let user = ConfigCatUser(identifier: "id", email: "test@example.com")

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValue() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let value = await client.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = await client.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetVariationId() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let details = await client.getValueDetails(for: "key1", defaultValue: false)
        XCTAssertEqual("fakeId1", details.variationId)
        let details2 = await client.getValueDetails(for: "key2", defaultValue: false, user: user)
        XCTAssertEqual("9f21c24c", details2.variationId)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetKeyValue() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let id = await client.getKeyAndValue(for: "fakeId1")
        XCTAssertEqual(true, id?.value as? Bool)
        XCTAssertEqual("key1", id?.key)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllKeys() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let keys = await client.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValues() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let values = await client.getAllValues()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValueDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let values = await client.getAllValueDetails()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefresh() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
        await client.forceRefresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertFalse(value)
        XCTAssertEqual(1, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let details = await client.getValueDetails(for: "key2", defaultValue: true)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertFalse(details.value)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        
        let initValue = testJsonMultiple.asEntryString()
        let cache = SingleValueCache(initValue: initValue)

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.hasUpToDateFlagData, state)
        XCTAssertEqual(0, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyExpiredCacheDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        
        let initValue = testJsonMultiple.asEntryString(date: Date().subtract(minutes: 5)!)
        let cache = SingleValueCache(initValue: initValue)

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.hasUpToDateFlagData, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyExpiredCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))
        
        let initValue = testJsonMultiple.asEntryString(date: Date().subtract(minutes: 5)!)
        let cache = SingleValueCache(initValue: initValue)

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.noFlagData, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyManualNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.noFlagData, state)
        XCTAssertEqual(0, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyManualCached() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))
        
        let initValue = testJsonMultiple.asEntryString()
        let cache = SingleValueCache(initValue: initValue)

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientReadyState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(0, engine.requests.count)
    }
    #endif
}
