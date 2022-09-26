import XCTest
@testable import ConfigCat

class ConfigCatClientTests: XCTestCase {
    let testJsonFormat = #"{ "f": { "fakeKey": { "v": %@, "p": [], "r": [] } } }"#
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testGetIntValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(43, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetIntValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetIntValueFailedInvalidJson() {
        MockHTTP.enqueueResponse(response: Response(body: "{", statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetStringValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetStringValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "33"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("def", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetDoubleValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43.56"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(43.56, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetDoubleValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(3.14, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetBoolValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "true"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertTrue(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetBoolValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertFalse(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetValueWithInvalidTypeFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: Float(55)) { value in
                XCTAssertEqual(Float(55), value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetLatestOnFail() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "55"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = createClient()
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testForceRefreshLazy() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: MockHTTP.session())

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testForceRefreshAuto() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testFailingAutoPoll() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testRequestTimeout() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200, delay: 3))
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session(config: config))
        let expectation1 = self.expectation(description: "wait for response")
        let start = Date()
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }

    func testFromCacheOnly() throws {
        let cache = InMemoryConfigCache()
        let sdkKey = "test"
        let keyToHash = "swift_" + Constants.configJsonName + "_" + sdkKey
        let cacheKey = String(keyToHash.sha1hex ?? keyToHash)
        try cache.write(for: cacheKey, value: String(format: testJsonFormat, "\"fake\"").toEntryFromConfigString().toJsonString())
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session(), configCache: cache)
        let expectation = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("fake", value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testFromCacheOnlyRefresh() throws {
        let cache = InMemoryConfigCache()
        let sdkKey = "test"
        let keyToHash = "swift_" + Constants.configJsonName + "_" + sdkKey
        let cacheKey = String(keyToHash.sha1hex ?? keyToHash)
        try cache.write(for: cacheKey, value: String(format: testJsonFormat, "\"fake\"").toEntryFromConfigString().toJsonString())
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))

        let client = ConfigCatClient(sdkKey: sdkKey, refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session(), configCache: cache)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testFailingAutoPollRefresh() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("", value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testFailingExpiringCache() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testGetAllValues() {
        MockHTTP.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = createClient()
        let expectation1 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getAllValues { allValues in
                XCTAssertEqual(2, allValues.count)
                XCTAssertEqual(true, allValues["key1"] as! Bool)
                XCTAssertEqual(false, allValues["key2"] as! Bool)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testAutoPollUserAgentHeader() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(), session: MockHTTP.session())
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual("ConfigCat-Swift/a-" + Constants.version, MockHTTP.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testLazyUserAgentHeader() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(), session: MockHTTP.session())
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual("ConfigCat-Swift/l-" + Constants.version, MockHTTP.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testManualPollUserAgentHeader() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual("ConfigCat-Swift/m-" + Constants.version, MockHTTP.requests.last?.value(forHTTPHeaderField: "X-ConfigCat-UserAgent"))
    }

    func testOnlineOffline() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(1, MockHTTP.requests.count)
        client.setOffline()

        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)

        XCTAssertEqual(1, MockHTTP.requests.count)
        client.setOnline()

        let expectation3 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 2)

        XCTAssertEqual(2, MockHTTP.requests.count)
    }

    func testDefaultUser() {
        MockHTTP.enqueueResponse(response: Response(body: Utils.createTestConfigWithRules().toJsonString(), statusCode: 200))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        let user1 = ConfigCatUser(identifier: "test@test1.com")
        let user2 = ConfigCatUser(identifier: "test@test2.com")

        client.setDefaultUser(user: user1)

        let expectation2 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "") { val in
            XCTAssertEqual("fake1", val)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)

        let expectation3 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "", user: user2) { val in
            XCTAssertEqual("fake2", val)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 2)

        client.clearDefaultUser()

        let expectation4 = self.expectation(description: "wait for response")
        client.getValue(for: "key", defaultValue: "") { val in
            XCTAssertEqual("def", val)
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 2)
    }

    func testHooks() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
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
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session(), hooks: hooks)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertTrue(r.success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertFalse(r.success)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)

        XCTAssertTrue(changed)
        XCTAssertTrue(ready)
        XCTAssertEqual("Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: 500", error)
    }

    func testHooksSub() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        var error = ""
        var changed = false
        let hooks = Hooks()
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session(), hooks: hooks)
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
        wait(for: [expectation], timeout: 2)
        let expectation2 = self.expectation(description: "wait for response")
        client.forceRefresh { r in
            XCTAssertFalse(r.success)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)

        XCTAssertTrue(changed)
        XCTAssertEqual("Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: 500", error)
    }

    private func createClient() -> ConfigCatClient {
        ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
    }
}
