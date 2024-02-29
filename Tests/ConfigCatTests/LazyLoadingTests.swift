import XCTest
@testable import ConfigCat

class LazyLoadingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#

    func testGet() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200, delay: 2))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        //wait for cache invalidation
        sleep(3)

        let expectation3 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test2", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 4)
    }

    func testGetFailedRefresh() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        //wait for cache invalidation
        sleep(3)

        let expectation3 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)
    }

    func testCache() throws {
        let engine = MockEngine()
        let mockCache = InMemoryConfigCache()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test") ?? false)

        //wait for cache invalidation
        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test2", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test2") ?? false)
    }

    func testCacheFails() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: DataGovernance.global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        //wait for cache invalidation
        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { result in
            XCTAssertEqual("test2", result.settings["fakeKey"]?.value.stringValue as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testCacheExpirationRespectedInTTLCalc() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        sleep(1)

        let expectation3 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        let expectation4 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
    }

    func testCacheExpirationRespectedInTTLCalc304() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 304))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        sleep(1)

        let expectation3 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        let expectation4 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
    }

    func testOnlineOffline() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        service.setOffline()
        Thread.sleep(forTimeInterval: 1.5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)

        service.setOnline()

        let expectation3 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(2, engine.requests.count)
    }

    func testInitOffline() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        Thread.sleep(forTimeInterval: 1.5)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(0, engine.requests.count)

        service.setOnline()

        let expectation3 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 5)

        XCTAssertEqual(1, engine.requests.count)
    }
}
