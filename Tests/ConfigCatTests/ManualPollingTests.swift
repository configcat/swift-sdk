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
        let fetcher = ConfigFetcher(session: MockHTTP.session(),logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 4)
    }

    func testGetFailedRefresh() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(),logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(),logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: testJsonFormat, "test"), mockCache.store.values.first)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: testJsonFormat, "test2"), mockCache.store.values.first)
    }

    func testCacheFails() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: MockHTTP.session(),logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, sdkKey: "")

        let expectation1 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        service.refresh {
            service.settings { settings in
                XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }
}
