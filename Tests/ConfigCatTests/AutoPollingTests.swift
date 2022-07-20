import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testGet() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testGetFailedRequest() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testOnConfigChanged() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        var called = false
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2, onConfigChanged: { () in
            called = true
        })
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        sleep(1)

        XCTAssertTrue(called)

        sleep(3)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testRequestTimeout() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 3))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        sleep(2)

        XCTAssertEqual(1, MockHTTP.requests.count)

        sleep(2)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testInitWaitTimeTimeout() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, sdkKey: "")

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertTrue(settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        print(elapsedTimeInSeconds)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, sdkKey: "")

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: testJsonFormat, "test"), mockCache.store.values.first)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: testJsonFormat, "test2"), mockCache.store.values.first)
    }

    func testCacheFails() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, sdkKey: "")

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settings in
            XCTAssertEqual("test2", (settings["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2)
    }

}
