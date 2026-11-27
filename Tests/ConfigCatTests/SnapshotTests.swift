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
        client.hooks.addOnReady(handler: { _ in
            expectation.fulfill()
        })
        client.start()
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
        client.hooks.addOnReady(handler: { _ in
            expectation.fulfill()
        })
        client.start()
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let keys = snapshot.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }

    func testUntypedSnapshotValueUsesAnyRatherThanFallbackType() {
        let overrides = LocalDictionaryDataSource(source: ["flag": true], behaviour: .localOnly)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: MockEngine(), flagOverrides: overrides).ensureStarted()
        defer { client.close() }
        let snapshot = client.snapshot()
        let fallback = NSMutableArray(array: ["fallback"])

        XCTAssertEqual(snapshot.getAnyValue(for: "flag", defaultValue: fallback, user: nil) as? Bool, true)
        XCTAssertEqual(snapshot.getAnyValue(for: "flag", defaultValue: "fallback", user: nil) as? Bool, true)
        XCTAssertTrue(snapshot.getAnyValue(for: "missing", defaultValue: fallback, user: nil) as? NSMutableArray === fallback)
        XCTAssertEqual(snapshot.getAnyValueDetails(for: "flag", defaultValue: fallback, user: nil).value as? Bool, true)
    }


    func testDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady(handler: { _ in
            expectation.fulfill()
        })
        client.start()
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let details = snapshot.getValueDetails(for: "key2", defaultValue: true)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertFalse(details.value)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSnapshotEvaluatesSensitiveTargetingWithConfigSalt() async {
        let json = #"""
        {"p":{"s":"test-salt"},"f":{"flag":{"t":0,"v":{"b":false},"r":[{"c":[{"u":{"a":"Identifier","c":20,"s":"5a44b77e7ef5591d88bd1509ddba6228bf9b0c805b0cb98a39af742d93103de7"}}],"s":{"v":{"b":true}}}]}}}
        """#
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: json, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }
        await client.waitForReady()

        let snapshot = client.snapshot()
        XCTAssertTrue(snapshot.getValue(for: "flag", defaultValue: false, user: ConfigCatUser(identifier: "user-1")))
        XCTAssertFalse(snapshot.getValue(for: "flag", defaultValue: true, user: ConfigCatUser(identifier: "user-2")))
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSnapshotEvaluationsAcrossTasks() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }
        await client.waitForReady()

        let snapshot = client.snapshot()
        let user = self.user
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<32 {
                group.addTask {
                    snapshot.getValue(for: "key2", defaultValue: false, user: user)
                }
            }
            var values: [Bool] = []
            for await value in group {
                values.append(value)
            }
            return values
        }
        XCTAssertEqual(results.count, 32)
        XCTAssertTrue(results.allSatisfy { $0 })
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueWait() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        await client.waitForReady()
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testClientState() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 200))
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 1), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        await client.waitForReady()
        let snapshot = client.snapshot()
        
        XCTAssertEqual([], snapshot.getAllKeys())
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testInvalidInput() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
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
        let hookCalled = expectation(description: "config changed hook called")
        hooks.addOnConfigChanged { _, snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "key1", defaultValue: false)
            XCTAssertTrue(value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshot() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let hooks = Hooks()
        let hookCalled = expectation(description: "ready hook called")
        
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "key1", defaultValue: false)
            XCTAssertTrue(value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date())
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "cached config changed hook called")
        hooks.addOnConfigChanged { _, snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date())
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "cached ready hook called")
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotCacheExpired() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date().subtract(months: 1)!)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "expired config changed hook called")
        hooks.addOnConfigChanged { _, snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotCacheExpired() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date().subtract(months: 1)!)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "expired ready hook called")
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testHookSnapshotManual() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "manual config changed hook called")
        hooks.addOnConfigChanged { _, snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyHookSnapshotManual() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        
        let hooks = Hooks()
        let hookCalled = expectation(description: "manual ready hook called")
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, snapshot.cacheState)
            let value = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("test1", value)
            hookCalled.fulfill()
        }
        
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, configCache: cache).ensureStarted()
        let state = await client.waitForReady()
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        
        await fulfillment(of: [hookCalled], timeout: 5)
    }
    #endif
}
