import XCTest
@testable import ConfigCat

class ConfigCatClientTests: XCTestCase {
    let testJsonFormat = #"{ "f": { "fakeKey": { "v": %@, "p": [], "r": [] } } }"#
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [] } } }"#

    func testGetIntValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "33"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43.56"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "true"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "55"), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), httpEngine: engine)

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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), httpEngine: engine)

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
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), httpEngine: engine)
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
        let sdkKey = "test"
        let keyToHash = "swift_" + Constants.configJsonName + "_" + sdkKey
        let cacheKey = String(keyToHash.sha1hex ?? keyToHash)
        try cache.write(for: cacheKey, value: String(format: testJsonFormat, "\"fake\"").toEntryFromConfigString().toJsonString())
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), httpEngine: engine, configCache: cache)
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
        let sdkKey = "test"
        let keyToHash = "swift_" + Constants.configJsonName + "_" + sdkKey
        let cacheKey = String(keyToHash.sha1hex ?? keyToHash)
        try cache.write(for: cacheKey, value: String(format: testJsonFormat, "\"fake\"").toEntryFromConfigString().toJsonString())
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), httpEngine: engine, configCache: cache)
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
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), httpEngine: engine)
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
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), httpEngine: engine)
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.lazyLoad(), httpEngine: engine)
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
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.lazyLoad(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.getValueDetails(for: "fakeKey", defaultValue: "") { details in
            XCTAssertEqual("", details.value)
            XCTAssertTrue(details.isDefaultValue)
            XCTAssertEqual("Config is not present. Returning defaultValue: [].", details.error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testManualPollUserAgentHeader() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
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
            XCTAssertEqual("The SDK is in offline mode, it can't initiate HTTP calls.", result.error)
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        var ready = false
        let hooks = Hooks()
        hooks.addOnReady {
            ready = true
        }
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine, hooks: hooks, offline: true)
        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
        XCTAssertTrue(ready)
    }

    func testDefaultUser() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: createTestConfigWithRules().toJsonString(), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
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
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))
        var error = ""
        var changed = false
        var ready = false
        let hooks = Hooks()
        hooks.addOnError { e in
            error = e
        }
        hooks.addOnReady {
            ready = true
        }
        hooks.addOnConfigChanged { _ in
            changed = true
        }
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine, hooks: hooks)
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
            changed && ready && error.starts(with: "Double-check your SDK Key at https://app.configcat.com/sdkkey.") && error.contains("404")
        }
    }

    func testHooksSub() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))
        var error = ""
        var changed = false
        let hooks = Hooks()
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine, hooks: hooks)
        client.hooks.addOnError { e in
            error = e
        }
        client.hooks.addOnConfigChanged { _ in
            changed = true
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
            changed && error.starts(with: "Double-check your SDK Key at https://app.configcat.com/sdkkey.") && error.contains("404")
        }
    }

    func testDefaultCache() {
        let engine = MockEngine()
        let cache = UserDefaultsCache()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "testDefaultCache", pollingMode: PollingModes.lazyLoad(), httpEngine: engine, configCache: cache)

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
        try XCTAssertFalse(cache.read(for: "ca67405a97c0f10ec01fdc65276fc6f4f009bc48").isEmpty)
    }

    func testOnFlagEvaluationError() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 500))
        let hooks = Hooks()
        var called = false
        hooks.addOnFlagEvaluated { details in
            XCTAssertEqual("", details.value as? String)
            XCTAssertEqual("Config is not present. Returning defaultValue: [].", details.error)
            XCTAssertTrue(details.isDefaultValue)
            called = true
        }
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.lazyLoad(), httpEngine: engine, hooks: hooks)
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
        var client1 = ConfigCatClient.get(sdkKey: "test")
        let client2 = ConfigCatClient.get(sdkKey: "test")

        XCTAssertEqual(client1, client2)

        ConfigCatClient.closeAll()
        client1 = ConfigCatClient.get(sdkKey: "test")

        XCTAssertNotEqual(client1, client2)
    }

    func testSingletonRemovesOnlyTheClosingInstance() {
        let client1 = ConfigCatClient.get(sdkKey: "test")

        client1.close()

        let client2 = ConfigCatClient.get(sdkKey: "test")

        XCTAssertNotEqual(client1, client2)

        client1.close()

        let client3 = ConfigCatClient.get(sdkKey: "test")

        XCTAssertEqual(client2, client3)
    }

    private func createClient(http: HttpEngine, offline: Bool = false) -> ConfigCatClient {
        ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: http, offline: offline)
    }
}
