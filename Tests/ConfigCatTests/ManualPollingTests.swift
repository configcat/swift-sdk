import XCTest
@testable import ConfigCat

class ManualPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#

    func testGet() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200, delay: 2))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 4)
    }

    func testGetFailedRefresh() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 404))

        var called = false
        let hooks = Hooks()
        hooks.addOnError { error in
            called = true
            XCTAssertTrue(error.starts(with: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey."))
        }
        let logger = InternalLogger(log: OSLogger(), level: .warning, hooks: hooks)

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: logger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertTrue(result.error?.starts(with: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey.") ?? false && result.error?.contains("404") ?? false)
            XCTAssertEqual(RefreshErrorCode.invalidSdkKey, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)

        waitFor {
            called
        }
    }
    
    func testFailedRequest() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String("test"), statusCode: 500))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual(result.error, "Unexpected HTTP response was received while trying to fetch config JSON: 500")
            XCTAssertEqual(RefreshErrorCode.unexpectedHttpResponse, result.errorCode)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }
    
    func testWrongBody() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String("{"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertTrue(result.error?.starts(with: "Fetching config JSON was successful but the HTTP response content was invalid. JSON parsing failed. The operation couldn’t be completed.") ?? false)
            XCTAssertEqual(RefreshErrorCode.invalidHttpResponseContent, result.errorCode)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }
    
    func testHttpError() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 200, error: TestError.test))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertTrue(result.error?.starts(with: "Unexpected error occurred while trying to fetch config JSON. It is most likely due to a local network issue. Please make sure your application can reach the ConfigCat CDN servers (or your proxy server) over HTTP.") ?? false)
            XCTAssertEqual(RefreshErrorCode.httpRequestFailure, result.errorCode)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }
    
    func testHttpTimeout() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(""), statusCode: 200, error: URLError(.timedOut)))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertTrue(result.error?.starts(with: "Request timed out while trying to fetch config JSON. Timeout value:") ?? false)
            XCTAssertEqual(RefreshErrorCode.httpRequestTimeout, result.errorCode)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testCache() throws {
        let engine = MockEngine()
        let mockCache = InMemoryConfigCache()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test") ?? false)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test2") ?? false)
    }

    func testCacheFails() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testEmptyCacheDoesNotInitiateHTTP() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)
    }

    func testOnlineOffline() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        service.setOffline()

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual("Client is in offline mode, it cannot initiate HTTP calls.", result.error)
            XCTAssertEqual(RefreshErrorCode.offlineClient, result.errorCode)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        service.setOnline()

        let expectation3 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(2, engine.requests.count)
    }

    func testInitOffline() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual("Client is in offline mode, it cannot initiate HTTP calls.", result.error)
            XCTAssertEqual(RefreshErrorCode.offlineClient, result.errorCode)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        service.setOnline()

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            XCTAssertEqual(RefreshErrorCode.none, result.errorCode)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
    }
}
