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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let value = await client.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = await client.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueWrongKey() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        let details = await client.getValueDetails(for: "non-existing", defaultValue: false)
        XCTAssertFalse(details.value)
        XCTAssertTrue(details.isDefaultValue)
        XCTAssertEqual(EvaluationErrorCode.settingKeyMissing, details.errorCode)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueTypeMismatch() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        let details = await client.getValueDetails(for: "key1", defaultValue: "")
        XCTAssertEqual("", details.value)
        XCTAssertTrue(details.isDefaultValue)
        XCTAssertEqual(EvaluationErrorCode.settingValueTypeMismatch, details.errorCode)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetVariationId() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let details = await client.getValueDetails(for: "key1", defaultValue: false)
        XCTAssertEqual("fakeId1", details.variationId)
        let details2 = await client.getValueDetails(for: "key2", defaultValue: false, user: user)
        XCTAssertEqual("9f21c24c", details2.variationId)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueDetailsAcrossTasks() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let user = self.user

        let details = await Task.detached {
            await client.getValueDetails(for: "key2", defaultValue: false, user: user)
        }.value
        XCTAssertTrue(details.value)
        XCTAssertEqual("9f21c24c", details.variationId)
        XCTAssertEqual("test@example.com", details.user?.attribute(for: ConfigCatUser.emailKey) as? String)
        XCTAssertEqual("Email", details.matchedTargetingRule?.conditions.first?.userCondition?.comparisonAttribute)
    }

    func testUntypedValueReturnsFlagAndPreservesUnsupportedFallback() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }
        let fallback = NSMutableArray(array: ["original"])
        let flagCompleted = expectation(description: "flag returned")
        let fallbackCompleted = expectation(description: "untyped fallback returned")
        client.getAnyValue(for: "key1", defaultValue: fallback, user: nil) { value in
            XCTAssertEqual(value as? Bool, true)
            flagCompleted.fulfill()
        }
        client.getAnyValue(for: "missing", defaultValue: fallback, user: nil) { value in
            XCTAssertTrue((value as? NSMutableArray) === fallback)
            fallbackCompleted.fulfill()
        }
        wait(for: [flagCompleted, fallbackCompleted], timeout: 5)
    }

    func testUntypedDetailsPreserveUnsupportedFallback() {
        let fallback = NSMutableArray(array: ["original"])
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: MockEngine()).ensureStarted()
        defer { client.close() }
        let completed = expectation(description: "untyped fallback returned")
        client.getAnyValueDetails(for: "missing", defaultValue: fallback, user: nil) { details in
            XCTAssertTrue((details.value as? NSMutableArray) === fallback)
            XCTAssertTrue(details.isDefaultValue)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetKeyValue() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let id = await client.getKeyAndValue(for: "fakeId1")
        XCTAssertEqual(true, id?.value as? Bool)
        XCTAssertEqual("key1", id?.key)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllKeys() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let keys = await client.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValues() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let values = await client.getAllValues()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetAllValueDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let values = await client.getAllValueDetails()
        XCTAssertEqual(2, values.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testScalarBulkResultsAcrossTasks() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }
        let user = self.user

        let values = await Task.detached { await client.getAllValues(user: user) }.value
        XCTAssertEqual(["key1": .bool(true), "key2": .bool(true)], values)

        let details = await Task.detached { await client.getAllValueDetails(user: user) }.value
        let byKey = Dictionary(uniqueKeysWithValues: details.map { ($0.key, $0) })
        XCTAssertEqual(.bool(true), byKey["key2"]?.value)
        XCTAssertEqual("9f21c24c", byKey["key2"]?.variationId)
        XCTAssertEqual("test@example.com", byKey["key2"]?.user?.attribute(for: ConfigCatUser.emailKey) as? String)
        XCTAssertEqual("Email", byKey["key2"]?.matchedTargetingRule?.conditions.first?.userCondition?.comparisonAttribute)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testScalarBulkValuesHandleTypesAndInvalidSettings() async {
        let source = TestDictionaryDataSource(
            source: ["bool": true, "string": "text", "int": 42, "double": 1.5, "invalid": NSObject()],
            behaviour: .localOnly
        )
        let logger = RecordingLogger()
        let hooks = Hooks()
        var evaluatedKeys = [String]()
        hooks.addOnFlagEvaluated { evaluatedKeys.append($0.key) }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: nil, hooks: hooks, flagOverrides: source).ensureStarted()
        defer { client.close() }

        let values = await client.getAllValues()
        XCTAssertEqual(["bool": .bool(true), "string": .string("text"), "int": .int(42), "double": .double(1.5)], values)
        XCTAssertEqual(Set(values.keys), Set(evaluatedKeys))
        XCTAssertTrue(logger.entries.contains { $0.contains("[1002]") && $0.contains("invalid") })

        let details = await client.getAllValueDetails()
        XCTAssertEqual(Set(values.keys), Set(details.map { $0.key }))
        XCTAssertEqual(8, evaluatedKeys.count)

        let completed = expectation(description: "values returned")
        client.getAllValues { completionValues in
            XCTAssertEqual(values, completionValues)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(12, evaluatedKeys.count)

        let detailsCompleted = expectation(description: "Objective-C details returned")
        client.getAllValueDetailsObjC { legacyDetails in
            XCTAssertEqual(Set(values.keys), Set(legacyDetails.map { $0.key }))
            XCTAssertEqual(true, legacyDetails.first { $0.key == "bool" }?.value as? Bool)
            detailsCompleted.fulfill()
        }
        await fulfillment(of: [detailsCompleted], timeout: 5)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testScalarBulkResultsWithoutConfiguration() async {
        let logger = RecordingLogger()
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: MockEngine()).ensureStarted()
        defer { client.close() }

        let values = await client.getAllValues()
        let details = await client.getAllValueDetails()
        XCTAssertTrue(values.isEmpty)
        XCTAssertTrue(details.isEmpty)
        XCTAssertEqual(2, logger.entries.filter { $0.contains("[1000]") }.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testTypedBulkResultsThroughClientProtocol() async {
        let source = TestDictionaryDataSource(source: ["flag": true], behaviour: .localOnly)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: nil, flagOverrides: source).ensureStarted()
        defer { client.close() }
        let protocolClient: ConfigCatClientProtocol = client

        let values = await protocolClient.getAllValues(user: nil)
        let details = await protocolClient.getAllValueDetails(user: nil)
        XCTAssertEqual(.bool(true), values["flag"])
        XCTAssertEqual(.bool(true), details.first?.value)

        let completed = expectation(description: "typed completion results")
        protocolClient.getAllValues(user: nil) { values in
            XCTAssertEqual(.bool(true), values["flag"])
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 5)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefresh() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let result = await client.forceRefresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertTrue(result.success)
        XCTAssertFalse(value)
        XCTAssertEqual(1, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefreshAndReadyStateAcrossTasks() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }

        let state = await Task.detached { await client.waitForReady() }.value
        XCTAssertEqual(.noFlagData, state)

        let result = await Task.detached { await client.forceRefresh() }.value
        XCTAssertTrue(result.success)
        XCTAssertEqual(.none, result.errorCode)

        client.setOffline()
        let failure = await Task.detached { await client.forceRefresh() }.value
        XCTAssertFalse(failure.success)
        XCTAssertEqual(.offlineClient, failure.errorCode)
        XCTAssertNotNil(failure.error)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testRefreshWithoutResult() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        await client.forceRefresh()
        let value = await client.getValue(for: "key2", defaultValue: true)
        XCTAssertFalse(value)
        XCTAssertEqual(1, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testDetails() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
        
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
        
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.noFlagData, state)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testReadyManualNoCacheFailedDownload() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 400))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
        
        let state = await client.waitForReady()
        
        XCTAssertEqual(ClientCacheState.hasCachedFlagDataOnly, state)
        XCTAssertEqual(0, engine.requests.count)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testWaitForReadyWhenClosedBeforeInitialization() async {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.autoPoll(maxInitWaitTimeInSeconds: 60)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: mode, logger: NoLogger(), httpEngine: engine).ensureStarted()
        let started = expectation(description: "ready waiter started")
        let completed = expectation(description: "ready waiter completes")
        completed.assertForOverFulfill = true
        Task {
            started.fulfill()
            let state = await client.waitForReady()
            XCTAssertEqual(.noFlagData, state)
            completed.fulfill()
        }

        await fulfillment(of: [started], timeout: 5)
        client.close()
        await fulfillment(of: [completed], timeout: 5)
        let lateCompleted = expectation(description: "ready waiter after close completes")
        Task {
            let state = await client.waitForReady()
            XCTAssertEqual(.noFlagData, state)
            lateCompleted.fulfill()
        }
        await fulfillment(of: [lateCompleted], timeout: 5)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testWaitForReadyPreservesStateAfterRefreshAndClose() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        defer { client.close() }

        let initialState = await client.waitForReady()
        XCTAssertEqual(.noFlagData, initialState)
        let refresh: RefreshResult = await client.forceRefresh()
        XCTAssertTrue(refresh.success)
        XCTAssertEqual(.hasCachedFlagDataOnly, client.snapshot().cacheState)

        client.close()
        let stateAfterClose = await client.waitForReady()
        XCTAssertEqual(initialState, stateAfterClose)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOfflineRefreshFromCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 304))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date().subtract(days: 2)!)
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: mode, logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()

        waitFor {
            engine.requests.count == 1
        }
        
        client.setOffline()
        XCTAssertTrue(client.isOffline)
        
        let val = await client.getValue(for: "fakeKey", defaultValue: "")
        XCTAssertEqual("test1", val)
        
        try! cache.write(for: "", value: String(format: testJsonFormat, "test2").asEntryString(date: Date().add(seconds: 1)!))
        
        let res = await client.forceRefresh()
        XCTAssertTrue(res.success)
        XCTAssertEqual(RefreshErrorCode.none, res.errorCode)
        
        let val2 = await client.getValue(for: "fakeKey", defaultValue: "")
        XCTAssertEqual("test2", val2)
        XCTAssertEqual(1, engine.requests.count)
        
        client.setOnline()
        XCTAssertFalse(client.isOffline)
        
        waitFor(timeout: 4) {
            engine.requests.count > 1
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOfflinePollRefreshesFromCache() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 304))

        let initValue = String(format: testJsonFormat, "test1").asEntryString(date: Date().subtract(days: 2)!)
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: mode, logger: NoLogger(), httpEngine: engine, configCache: cache, offline: true).ensureStarted()

        await client.waitForReady()
        
        waitFor {
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            return val == "test1"
        }
        
        try! cache.write(for: "", value: String(format: testJsonFormat, "test2").asEntryString(date: Date().subtract(days: 1)!))
        
        waitFor {
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            return val == "test2"
        }
        
        XCTAssertEqual(0, engine.requests.count)
    }
    #endif
}
