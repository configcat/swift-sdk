import XCTest
@testable import ConfigCat

class ManualPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testGet() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200, delay: 2))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

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
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        var called = false
        let hooks = Hooks()
        hooks.addOnError { error in
            called = true
            XCTAssertEqual("Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: 500", error)
        }
        let logger = Logger(level: .warning, hooks: hooks)

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: logger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: logger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertFalse(result.success)
            XCTAssertEqual("Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: 500", result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
        XCTAssertTrue(called)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

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
        wait(for: [expectation2], timeout: 2)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test2") ?? false)
    }

    func testCacheFails() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertNil(result.error)
            service.settings { settingsResult in
                XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testEmptyCacheDoesNotInitiateHTTP() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        XCTAssertEqual(0, MockHTTP.requests.count)
    }
}
