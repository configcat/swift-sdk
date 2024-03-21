import XCTest
@testable import ConfigCat

class ConfigCatClientTests: XCTestCase {
    let testJsonFormat = #"{ "f": { "fakeKey": { "v": { "%@": %@ }, "t": %@ } } }"#
    let testStringJson = #"{ "f": { "fakeKey": { "v": { "s": "fake" }, "t": 1 } } }"#
    let testJsonMultiple = #"{ "f": { "key1": { "v": { "b": true }, "t":0, "i": "fakeId1" }, "key2": { "v": { "b": false }, "i": "fakeId2", "t":0 } } }"#

    func testGetIntValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "i", "43", "2"), statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(43, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetIntValueFailed() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "i", "fake", "2"), statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetIntValueFailedInvalidJson() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "{", statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetStringValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetStringValueFailed() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "s", "33", "1"), statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("def", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetDoubleValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "d", "43.56", "3"), statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(43.56, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetDoubleValueFailed() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(3.14, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetBoolValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "b", "true", "0"), statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertTrue(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetBoolValueFailed() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertFalse(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetValueWithInvalidTypeFailed() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: Float(55)) { value in
                XCTAssertEqual(Float(55), value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetLatestOnFail() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "i", "55", "2"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = createClient(http: engine)
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testForceRefreshLazy() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "s", "\"test\"", "1"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "s", "\"test2\"", "1"), statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine)

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testForceRefreshAuto() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "s", "\"test\"", "1"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "s", "\"test2\"", "1"), statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine)

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testFailingAutoPoll() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine)
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testFromCacheOnly() throws {
        let engine = MockEngine()
        let cache = InMemoryConfigCache()
        let sdkKey = randomSdkKey()
        let cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
        try cache.write(for: cacheKey, value: testStringJson.toEntryFromConfigString().serialize())
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine, configCache: cache)
        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("fake", value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testFromCacheOnlyRefresh() throws {
        let engine = MockEngine()
        let cache = InMemoryConfigCache()
        let sdkKey = randomSdkKey()
        let cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
        try cache.write(for: cacheKey, value: testStringJson.toEntryFromConfigString().serialize())
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine, configCache: cache)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testFailingAutoPollRefresh() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine)
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("", value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testFailingExpiringCache() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine)
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testGetAllValues() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = createClient(http: engine)
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getAllValues { allValues in
                XCTAssertEqual(2, allValues.count)
                XCTAssertEqual(true, allValues["key1"] as! Bool)
                XCTAssertEqual(false, allValues["key2"] as! Bool)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testAutoPollUserAgentHeader() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual("ConfigCat-Swift/a-" + Constants.version, engine.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testLazyUserAgentHeader() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual("ConfigCat-Swift/l-" + Constants.version, engine.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testGetValueDetailsWithError() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.getValueDetails(for: "fakeKey", defaultValue: "") { details in
            XCTAssertEqual("", details.value)
            XCTAssertTrue(details.isDefaultValue)
            XCTAssertEqual("Config JSON is not present when evaluating setting 'fakeKey'. Returning the `defaultValue` parameter that you specified in your application: ''.", details.error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testManualPollUserAgentHeader() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual("ConfigCat-Swift/m-" + Constants.version, engine.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testOnlineOffline() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = createClient(http: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
        client.setOffline()

        XCTAssertTrue(client.isOffline)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual("Client is in offline mode, it cannot initiate HTTP calls.", result.error)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
        client.setOnline()

        let expectation3 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(2, engine.requests.count)
        XCTAssertFalse(client.isOffline)
    }

    func testInitOffline() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = createClient(http: engine, offline: true)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
        XCTAssertTrue(client.isOffline)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
        client.setOnline()

        let expectation3 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
        XCTAssertFalse(client.isOffline)
    }

    func testInitOfflineCallsReady() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        var ready = false
        var state = ClientReadyState.hasUpToDateFlagData
        let hooks = Hooks()
        hooks.addOnReady { st in
            ready = true
            state = st
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, offline: true)
        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
        XCTAssertTrue(ready)
        XCTAssertEqual(ClientReadyState.noFlagData, state)
    }

    func testDefaultUser() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: createTestConfigWithRules().toJsonString(), statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let user1 = ConfigCatUser(identifier: "test@test1.com")
        let user2 = ConfigCatUser(identifier: "test@test2.com")

        client.setDefaultUser(user: user1)

        let expectation2 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "") { val in
            XCTAssertEqual("fake1", val)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        let expectation3 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "", user: user2) { val in
            XCTAssertEqual("fake2", val)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        client.clearDefaultUser()

        let expectation4 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "") { val in
            XCTAssertEqual("def", val)
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 5)
    }

    func testHooks() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))
        var error = ""
        var changed = false
        var ready = false
        let hooks = Hooks()
        hooks.addOnError { e in
            error = e
        }
        hooks.addOnReady { state in
            ready = true
            XCTAssertEqual(ClientReadyState.noFlagData, state)
        }
        hooks.addOnConfigChanged { _ in
            changed = true
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertTrue(r.success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertFalse(r.success)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        waitFor {
            changed && ready && error.starts(with: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey.") && error.contains("404")
        }
        
        let expectation3 = self.expectation(description: "wait for ready second time")
        client.hooks.addOnReady { state in
            XCTAssertEqual(ClientReadyState.noFlagData, state)
            expectation3.fulfill()
        }
        let expectation4 = self.expectation(description: "wait for ready third time")
        client.hooks.addOnReady { state in
            XCTAssertEqual(ClientReadyState.noFlagData, state)
            expectation4.fulfill()
        }
        
        wait(for: [expectation3, expectation4], timeout: 5)
    }

    func testHooksSub() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))
        var error = ""
        var changed = false
        var ready = false
        let hooks = Hooks()
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        client.hooks.addOnError { e in
            error = e
        }
        client.hooks.addOnConfigChanged { _ in
            changed = true
        }
        client.hooks.addOnReady { state in
            ready = true
            XCTAssertEqual(ClientReadyState.noFlagData, state)
        }

        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertTrue(r.success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertFalse(r.success)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        waitFor {
            changed && ready && error.starts(with: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey.") && error.contains("404")
        }
    }
    
    func testReadyHookGetValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let expectation = self.expectation(description: "wait for response")
        
        client.hooks.addOnReady { state in
            XCTAssertEqual(ClientReadyState.hasUpToDateFlagData, state)
            client.getValue(for: "fakeKey", defaultValue: "") { val in
                XCTAssertEqual("fake", val)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }
    
    func testReadyHookGetValueSnapshot() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let expectation = self.expectation(description: "wait for response")
        
        client.hooks.addOnReady { state in
            XCTAssertEqual(ClientReadyState.hasUpToDateFlagData, state)
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("fake", val)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    func testLazyCache() throws {
        let engine = MockEngine()
        let cache = InMemoryConfigCache()
        let sdkKey = randomSdkKey()
        let cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine, configCache: cache)

        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { r in
            XCTAssertEqual("fake", r)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { r in
            XCTAssertEqual("fake", r)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
        try XCTAssertFalse(cache.read(for: cacheKey).isEmpty)
    }

    func testOnFlagEvaluationError() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let hooks = Hooks()
        var called = false
        hooks.addOnFlagEvaluated { details in
            XCTAssertEqual("", details.value as? String)
            XCTAssertEqual("Config JSON is not present when evaluating setting 'fakeKey'. Returning the `defaultValue` parameter that you specified in your application: ''.", details.error)
            XCTAssertTrue(details.isDefaultValue)
            called = true
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        waitFor {
            called
        }
    }

    func testSingleton() {
        let sdkKey = randomSdkKey()
        var client1 = ConfigCatClient.get(sdkKey: sdkKey)
        let client2 = ConfigCatClient.get(sdkKey: sdkKey)

        XCTAssertEqual(client1, client2)

        ConfigCatClient.closeAll()
        client1 = ConfigCatClient.get(sdkKey: sdkKey)

        XCTAssertNotEqual(client1, client2)
    }

    func testSingletonRemovesOnlyTheClosingInstance() {
        let sdkKey = randomSdkKey()
        
        let client1 = ConfigCatClient.get(sdkKey: sdkKey)

        client1.close()

        let client2 = ConfigCatClient.get(sdkKey: sdkKey)

        XCTAssertNotEqual(client1, client2)

        client1.close()

        let client3 = ConfigCatClient.get(sdkKey: sdkKey)

        XCTAssertEqual(client2, client3)
    }
    
    func testSdkKeyValidation() {
        let tests = [
            ("sdk-key-90123456789012", false, false),
            ("sdk-key-9012345678901/1234567890123456789012", false, false),
            ("sdk-key-90123456789012/123456789012345678901", false, false),
            ("sdk-key-90123456789012/12345678901234567890123", false, false),
            ("sdk-key-901234567890123/1234567890123456789012", false, false),
            ("sdk-key-90123456789012/1234567890123456789012", false, true),
            ("configcat-sdk-1/sdk-key-90123456789012", false, false),
            ("configcat-sdk-1/sdk-key-9012345678901/1234567890123456789012", false, false),
            ("configcat-sdk-1/sdk-key-90123456789012/123456789012345678901", false, false),
            ("configcat-sdk-1/sdk-key-90123456789012/12345678901234567890123", false, false),
            ("configcat-sdk-1/sdk-key-901234567890123/1234567890123456789012", false, false),
            ("configcat-sdk-1/sdk-key-90123456789012/1234567890123456789012", false, true),
            ("configcat-sdk-2/sdk-key-90123456789012/1234567890123456789012", false, false),
            ("configcat-proxy/", false, false),
            ("configcat-proxy/", true, false),
            ("configcat-proxy/sdk-key-90123456789012", false, false),
            ("configcat-proxy/sdk-key-90123456789012", true, true),
        ]
        
        for test in tests {
            let logger = RecordingLogger()
            let customUrl = test.1 ? "https://my-configcat-proxy" : ""
            let client = ConfigCatClient(sdkKey: test.0, pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: nil, baseUrl: customUrl)
            
            XCTAssertEqual(test.2, !client.isOffline)
            if !test.2 {
                XCTAssertEqual("ERROR [0] ConfigCat SDK Key '\(test.0)' is invalid.", logger.entries.last)
            }
        }
    }

    private func createClient(http: HttpEngine, offline: Bool = false) -> ConfigCatClient {
        ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: http, offline: offline)
    }
}
