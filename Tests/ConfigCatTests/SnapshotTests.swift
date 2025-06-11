import XCTest
@testable import ConfigCat

class SnapshotTests: XCTestCase {
    let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#
    let testJsonMultiple = #"{"f":{"key1":{"t":0,"v":{"b":true},"i":"fakeId1"},"key2":{"t":0,"r":[{"c":[{"u":{"a":"Email","c":2,"l":["@example.com"]}}],"s":{"v":{"b":true},"i":"9f21c24c"}}],"v":{"b":false},"i":"fakeId2"}}}"#
    let user = ConfigCatUser(identifier: "id", email: "test@example.com")

    func testGetValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let value = snapshot.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = snapshot.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }

    func testGetAllKeys() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
       
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let keys = snapshot.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }


    func testDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let details = snapshot.getValueDetails(for: "key2", defaultValue: true)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertFalse(details.value)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueWait() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        await client.waitForReady()
        
        let snapshot = client.snapshot()
        let value = snapshot.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = snapshot.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testWaitMultiple() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        await client.waitForReady()
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testClientState() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 200))
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 1), logger: NoLogger(), httpEngine: engine)
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.noFlagData, state)
        XCTAssertEqual(ClientCacheState.noFlagData, client.snapshot().cacheState)
        
        waitFor {
            client.snapshot().cacheState == .hasUpToDateFlagData
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllKeysEmpty() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        await client.waitForReady()
        let snapshot = client.snapshot()
        
        XCTAssertEqual([], snapshot.getAllKeys())
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testInvalidInput() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        await client.waitForReady()
        
        let snapshot = client.snapshot()
        let details = snapshot.getValueDetails(for: "key", defaultValue: UInt8())
        
        XCTAssertEqual(EvaluationErrorCode.invalidUserInput, details.errorCode)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshot() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let hooks = Hooks()
        var called = false
        hooks.addOnConfigChangedWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "key1", defaultValue: false)
            XCTAssertTrue(value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshot() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let hooks = Hooks()
        var called = false
        hooks.addOnReadyWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "key1", defaultValue: false)
            XCTAssertTrue(value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date())
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnConfigChangedWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date())
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnReadyWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotCacheExpired() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnConfigChangedWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotCacheExpired() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnReadyWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotManual() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnConfigChangedWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        waitFor {
            called
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotManual() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        var called = false
        hooks.addOnReadyWithSnapshot { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            called = true
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache)
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        waitFor {
            called
        }
    }
    #endif
}
