import XCTest
@testable import ConfigCat

class AsyncAwaitTests: XCTestCase {
    #if compiler(>=5.5) && canImport(_Concurrency)
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#
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
    func testGetValueWrongKey() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let details = await client.getValueDetails(for: "non-existing", defaultValue: false)
        XCTAssertFalse(details.value)
        XCTAssertTrue(details.isDefaultValue)
        XCTAssertEqual(EvaluationErrorCode.settingKeyMissing, details.errorCode)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueTypeMismatch() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let details = await client.getValueDetails(for: "key1", defaultValue: "")
        XCTAssertEqual("", details.value)
        XCTAssertTrue(details.isDefaultValue)
        XCTAssertEqual(EvaluationErrorCode.settingValueTypeMismatch, details.errorCode)
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
        
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
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
        
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
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
        
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.noFlagData, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyManualNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.noFlagData, state)
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
        
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(0, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOfflineRefreshFromCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 304))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: mode, logger: NoLogger(), httpEngine: engine, configCache: cache)

        waitFor {
            engine.requests.count == 1
        }
        
        client.setOffline()
        XCTAssertTrue(client.isOffline)
        
        let val = await client.getValue(for: "fakeKey", defaultValue: "")
        XCTAssertEqual("test1", val)
        
        try! cache.write(for: "", value: String(format: testJsonFormat, "test2").asEntryString(date: Date.distantPast))
        
        let res = await client.forceRefresh()
        XCTAssertTrue(res.success)
        XCTAssertEqual(RefreshErrorCode.none, res.errorCode)
        
        let val2 = await client.getValue(for: "fakeKey", defaultValue: "")
        XCTAssertEqual("test2", val2)
        XCTAssertEqual(1, engine.requests.count)
        
        client.setOnline()
        XCTAssertFalse(client.isOffline)
        
        waitFor {
            engine.requests.count > 1
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOfflinePollRefreshesFromCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 304))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: mode, logger: NoLogger(), httpEngine: engine, configCache: cache, offline: true)

        await client.waitForReady()
        
        waitFor {
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            return val == "test1"
        }
        
        try! cache.write(for: "", value: String(format: testJsonFormat, "test2").asEntryString(date: Date.distantPast))
        
        waitFor {
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            return val == "test2"
        }
        
        XCTAssertEqual(0, engine.requests.count)
    }
    #endif
}
