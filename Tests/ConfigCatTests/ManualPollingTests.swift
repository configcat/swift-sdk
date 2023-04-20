import XCTest
@testable import ConfigCat

class ManualPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    func testGet() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200, delay: 2))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
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
        let logger = Logger(level: .warning, hooks: hooks)

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: logger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertTrue(result.error?.starts(with: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey.") ?? false && result.error?.contains("404") ?? false)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)

        waitFor {
            called
        }
    }

    func testCache() throws {
        let engine = MockEngine()
        let mockCache = InMemoryConfigCache()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
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
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
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
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testEmptyCacheDoesNotInitiateHTTP() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

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

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

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
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        service.setOnline()

        let expectation3 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(2, engine.requests.count)
    }

    func testInitOffline() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true)

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual("Client is in offline mode, it cannot initiate HTTP calls.", result.error)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        service.setOnline()

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
    }
}
