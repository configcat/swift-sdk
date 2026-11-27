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
        client.forceRefresh { res in
            XCTAssertEqual(RefreshErrorCode.invalidHttpResponseContent, res.errorCode)
            client.getValueDetails(for: "fakeKey", defaultValue: 10) { details in
                XCTAssertEqual(EvaluationErrorCode.configJsonNotAvailable, details.errorCode)
                XCTAssertEqual(10, details.value)
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
            client.getValueDetails(for: "fakeKey", defaultValue: 10) { details in
                XCTAssertEqual(EvaluationErrorCode.configJsonNotAvailable, details.errorCode)
                XCTAssertEqual(10, details.value)
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine).ensureStarted()

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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine).ensureStarted()

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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        try cache.write(for: cacheKey, value: testStringJson.toEntryFromConfigString().cacheString)
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
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
        try cache.write(for: cacheKey, value: testStringJson.toEntryFromConfigString().cacheString)
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()
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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
                XCTAssertEqual(.bool(true), allValues["key1"])
                XCTAssertEqual(.bool(false), allValues["key2"])
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testAutoPollUserAgentHeader() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let hooks = Hooks()
        let ready = expectation(description: "offline ready hook called")
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.noFlagData, snapshot.cacheState)
            ready.fulfill()
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks, offline: true).ensureStarted()
        let value = expectation(description: "value returned")
        client.getValue(for: "fakeKey", defaultValue: "") { _ in
            value.fulfill()
        }
        wait(for: [value, ready], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
    }

    func testDefaultUser() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: createTestConfigWithRules().toJsonString(), statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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
        let hooks = Hooks()
        let error = expectation(description: "error hook called")
        let changed = expectation(description: "config changed hook called")
        let ready = expectation(description: "ready hook called")
        hooks.addOnError { e in
            XCTAssertTrue(e.starts(with: "Your SDK Key seems to be wrong: '"))
            XCTAssertTrue(e.contains("You can find the valid SDK Key at https://app.configcat.com/sdkkey."))
            XCTAssertTrue(e.contains("404"))
            error.fulfill()
        }
        hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.noFlagData, snapshot.cacheState)
            ready.fulfill()
        }
        hooks.addOnConfigChanged { (_, _) in
            changed.fulfill()
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks).ensureStarted()
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

        wait(for: [error, changed, ready], timeout: 5)
        
        let lateReady = self.expectation(description: "late ready handler is not called")
        lateReady.isInverted = true
        client.hooks.addOnReady(handler: { _ in lateReady.fulfill() })
        wait(for: [lateReady], timeout: 0.1)
    }

    func testHooksSub() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))
        let hooks = Hooks()
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine, hooks: hooks)
        let error = expectation(description: "error hook called")
        let changed = expectation(description: "config changed hook called")
        let ready = expectation(description: "ready hook called")
        client.hooks.addOnError { e in
            XCTAssertTrue(e.starts(with: "Your SDK Key seems to be wrong: '"))
            XCTAssertTrue(e.contains("You can find the valid SDK Key at https://app.configcat.com/sdkkey."))
            XCTAssertTrue(e.contains("404"))
            error.fulfill()
        }
        client.hooks.addOnConfigChanged { (_, _) in
            changed.fulfill()
        }
        client.hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.noFlagData, snapshot.cacheState)
            ready.fulfill()
        }
        client.start()

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

        wait(for: [error, changed, ready], timeout: 5)
    }
    
    func testReadyHookGetValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let expectation = self.expectation(description: "wait for response")
        
        client.hooks.addOnReady { snapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
            client.getValue(for: "fakeKey", defaultValue: "") { val in
                XCTAssertEqual("fake", val)
                expectation.fulfill()
            }
        }

        client.start()
        wait(for: [expectation], timeout: 5)
    }
    
    func testReadyHookGetValueSnapshot() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine)
        
        let expectation = self.expectation(description: "wait for response")
        
        client.hooks.addOnReady { readySnapshot in
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, readySnapshot.cacheState)
            let snapshot = client.snapshot()
            let val = snapshot.getValue(for: "fakeKey", defaultValue: "")
            XCTAssertEqual("fake", val)
            expectation.fulfill()
        }

        client.start()
        wait(for: [expectation], timeout: 5)
    }

    func testLazyCache() throws {
        let engine = MockEngine()
        let cache = InMemoryConfigCache()
        let sdkKey = randomSdkKey()
        let cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))
        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine, configCache: cache).ensureStarted()

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
        let flagEvaluated = expectation(description: "flag evaluated hook called")
        hooks.addOnFlagEvaluated { details in
            XCTAssertEqual("", details.value as? String)
            XCTAssertEqual("Config JSON is not present when evaluating setting 'fakeKey'. Returning the `defaultValue` parameter that you specified in your application: ''.", details.error)
            XCTAssertTrue(details.isDefaultValue)
            flagEvaluated.fulfill()
        }
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(), logger: NoLogger(), httpEngine: engine, hooks: hooks).ensureStarted()
        let valueReturned = self.expectation(description: "default value returned")
        client.getValue(for: "fakeKey", defaultValue: "") { result in
            XCTAssertEqual("", result)
            valueReturned.fulfill()
        }
        wait(for: [valueReturned, flagEvaluated], timeout: 5)
    }

    func testFlagEvaluatedHookUnwrapsFlagValues() {
        let hooks = Hooks()
        let evaluated = expectation(description: "flag evaluated hooks")
        evaluated.expectedFulfillmentCount = 9
        hooks.addOnFlagEvaluated { details in
            XCTAssertFalse(details.value is FlagValue)
            switch details.key {
            case "flag":
                XCTAssertEqual(details.value as? Bool, true)
                XCTAssertFalse(details.isDefaultValue)
            case "missing":
                XCTAssertEqual(details.value as? Int, 42)
                XCTAssertTrue(details.isDefaultValue)
            case "invalid":
                XCTAssertEqual(details.value as? String, "fallback")
                XCTAssertTrue(details.isDefaultValue)
            case "empty":
                XCTAssertEqual(details.value as? Double, 1.5)
                XCTAssertTrue(details.isDefaultValue)
            case "nil":
                let mirror = Mirror(reflecting: details.value)
                XCTAssertEqual(mirror.displayStyle, .optional)
                XCTAssertTrue(mirror.children.isEmpty)
                XCTAssertTrue(details.isDefaultValue)
            default:
                XCTFail("Unexpected key: \(details.key)")
            }
            evaluated.fulfill()
        }

        let source = TestDictionaryDataSource(source: ["flag": true, "invalid": NSObject()], behaviour: .localOnly)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: nil, hooks: hooks, flagOverrides: source).ensureStarted()
        defer { client.close() }
        let snapshot = client.snapshot()

        XCTAssertEqual(snapshot.getValue(for: "flag", defaultValue: FlagValue.bool(false)), .bool(true))
        XCTAssertEqual(snapshot.getValue(for: "flag", defaultValue: Optional<FlagValue>.none), .bool(true))
        XCTAssertTrue(snapshot.getValue(for: "flag", defaultValue: false))
        XCTAssertEqual(snapshot.getValueDetails(for: "missing", defaultValue: Optional<FlagValue>.some(.int(42))).value, .int(42))
        XCTAssertEqual(snapshot.getValue(for: "invalid", defaultValue: FlagValue.string("fallback")), .string("fallback"))
        XCTAssertNil(snapshot.getValue(for: "nil", defaultValue: Optional<FlagValue>.none))

        let valueCompleted = expectation(description: "scalar value returned")
        client.getValue(for: "flag", defaultValue: FlagValue.bool(false)) { value in
            XCTAssertEqual(value, .bool(true))
            valueCompleted.fulfill()
        }

        let bulkCompleted = expectation(description: "bulk values returned")
        client.getAllValues { values in
            XCTAssertEqual(values["flag"], .bool(true))
            bulkCompleted.fulfill()
        }

        let emptySource = TestDictionaryDataSource(source: [:], behaviour: .localOnly)
        let emptyClient = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: nil, hooks: hooks, flagOverrides: emptySource).ensureStarted()
        defer { emptyClient.close() }
        XCTAssertEqual(emptyClient.snapshot().getValue(for: "empty", defaultValue: FlagValue.double(1.5)), .double(1.5))

        wait(for: [evaluated, valueCompleted, bulkCompleted], timeout: 5)
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

    func testMask() {
        let cases = [
            ("", ""),
            ("abc123", "abc123"),
            ("/abc123", "/abc123"),
            ("abc/123", "*bc/123"),
            ("abc123/", "*bc123/"),
            ("configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012", "***************/**********************/****************789012"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(expected, Utils.mask(input))
        }
    }

    func testExistingClientWarningMasksSdkKey() {
        let sdkKey = "sdk-key-90123456789012/1234567890123456789012"
        let logger = RecordingLogger()
        let options = ConfigCatOptions()
        options.pollingMode = PollingModes.manualPoll()
        options.configCache = nil
        options.logger = logger
        let client = ConfigCatClient.get(sdkKey: sdkKey, options: options)
        defer { client.close() }

        let existing = ConfigCatClient.get(sdkKey: sdkKey, options: options)
        XCTAssertTrue(client === existing)
        XCTAssertEqual(
            "WARNING [3000] There is an existing client instance for the specified SDK Key. No new client instance will be created and the specified configuration action is ignored. Returning the existing client instance. SDK Key: '\(String(repeating: "*", count: 22))/\(String(repeating: "*", count: 16))789012'.",
            logger.logs.last
        )
    }

    func testReadyHookCanGetRegisteredClient() {
        for (mode, localOnly) in [(PollingModes.manualPoll(), false), (PollingModes.lazyLoad(), false), (PollingModes.manualPoll(), true)] {
            let completed = expectation(description: "ready callback can get client")
            DispatchQueue.global().async {
                let sdkKey = randomSdkKey()
                let options = ConfigCatOptions()
                options.pollingMode = mode
                options.configCache = nil
                options.logger = NoLogger()
                if localOnly {
                    options.flagOverrides = LocalDictionaryDataSource(source: [:], behaviour: .localOnly)
                }
                let registered = Locked<ConfigCatClient?>(nil)
                options.hooks.addOnReady(handler: { _ in
                    registered.withLock { $0 = ConfigCatClient.get(sdkKey: sdkKey) }
                })
                let client = ConfigCatClient.get(sdkKey: sdkKey, options: options)
                XCTAssertTrue(client === registered.withLock { $0 })
                client.close()
                completed.fulfill()
            }
            wait(for: [completed], timeout: 5)
        }
    }

    func testCloseCompletionCanReenterClientRegistry() {
        let engine = MockEngine(autoRespond: false)
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        let completed = expectation(description: "pending refresh completes during close")
        completed.assertForOverFulfill = true
        client.forceRefresh { _ in
            let options = ConfigCatOptions()
            options.pollingMode = PollingModes.manualPoll()
            options.configCache = nil
            options.logger = NoLogger()
            let replacement = ConfigCatClient.get(sdkKey: randomSdkKey(), options: options)
            replacement.close()
            client.close()
            ConfigCatClient.closeAll()
            completed.fulfill()
        }
        XCTAssertEqual(1, engine.requests.count)
        DispatchQueue.global().async { client.close() }
        wait(for: [completed], timeout: 5)
        engine.respond(Response(body: "", statusCode: 304))
    }

    func testConcurrentGetReturnsOneClient() {
        let sdkKey = randomSdkKey()
        let options = ConfigCatOptions()
        options.pollingMode = PollingModes.manualPoll()
        options.configCache = nil
        options.logger = NoLogger()
        let lock = NSLock()
        var clients = [ConfigCatClient]()
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            let client = ConfigCatClient.get(sdkKey: sdkKey, options: options)
            lock.lock()
            clients.append(client)
            lock.unlock()
        }
        XCTAssertEqual(clients.count, 16)
        XCTAssertTrue(clients.allSatisfy { $0 === clients.first })
        clients.first?.close()
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
            let hooks = Hooks()
            let expected = "ConfigCat SDK Key '\(Utils.mask(test.0))' is invalid."
            let errorReported = test.2 ? nil : expectation(description: "invalid SDK key reported")
            errorReported?.assertForOverFulfill = true
            hooks.addOnError { error in
                if let errorReported = errorReported {
                    XCTAssertEqual(expected, error)
                    errorReported.fulfill()
                }
            }
            let customUrl = test.1 ? "https://my-configcat-proxy" : ""
            let client = ConfigCatClient(sdkKey: test.0, pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: nil, hooks: hooks, baseUrl: customUrl).ensureStarted()
            
            XCTAssertEqual(test.2, !client.isOffline)
            if let errorReported = errorReported {
                XCTAssertEqual("ERROR [0] \(expected)", logger.logs.last)
                wait(for: [errorReported], timeout: 5)
            }
        }
    }

    private func createClient(http: HttpEngine, offline: Bool = false) -> ConfigCatClient {
        ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: http, offline: offline).ensureStarted()
    }
}
