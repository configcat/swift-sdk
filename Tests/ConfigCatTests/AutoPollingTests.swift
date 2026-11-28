import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#

    func testPollingIntervalBounds() throws {
        let cases = [
            (Int.min, 1), (0, 1), (1, 1), (60, 60),
            (31_536_000, 31_536_000), (31_536_001, 31_536_000), (Int.max, 31_536_000)
        ]
        for (input, expected) in cases {
            let auto = try XCTUnwrap(PollingModes.autoPoll(autoPollIntervalInSeconds: input, maxInitWaitTimeInSeconds: input) as? AutoPollingMode)
            let lazy = try XCTUnwrap(PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: input) as? LazyLoadingMode)
            XCTAssertEqual(expected, auto.autoPollIntervalInSeconds)
            XCTAssertEqual(expected, auto.maxInitWaitTimeInSeconds)
            XCTAssertEqual(expected, lazy.cacheRefreshIntervalInSeconds)
        }
    }

    func testMaximumCacheIntervalSupportsSettingsAndReadyState() throws {
        let entry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "cached"), eTag: "cached", fetchTime: Date()
        ).get()
        let cache = SingleValueCache(initValue: entry.cacheString)
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: Int.max)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true).ensureStarted()
        defer { service.close() }

        XCTAssertEqual(.hasUpToDateFlagData, service.inMemory.cacheState)
        let settings = expectation(description: "cached settings returned")
        service.settings { result in
            XCTAssertEqual("cached", result.settings["fakeKey"]?.value.stringValue)
            settings.fulfill()
        }
        wait(for: [settings], timeout: 5)
        XCTAssertTrue(engine.requests.isEmpty)
    }

    func testGet() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testGetFailedRequest() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testOnConfigChanged() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let configChanged = expectation(description: "config changed hook called")
        configChanged.assertForOverFulfill = false
        let hooks = Hooks()
        hooks.addOnConfigChanged { (_, _) in
            configChanged.fulfill()
        }
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false).ensureStarted()

        wait(for: [configChanged], timeout: 5)

        sleep(3)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testRequestTimeout() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 3))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        sleep(2)

        XCTAssertEqual(1, engine.requests.count)

        sleep(2)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testInitWaitTimeTimeout() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test") ?? false)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
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

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value.stringValue)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testPollIntervalRespectsCacheExpiration() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "updated"), statusCode: 200))

        let initValue = String(format: testJsonFormat, "cached").asEntryString(date: Date().addingTimeInterval(5))
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let hooks = Hooks()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
        defer { service.close() }

        let ready = expectation(description: "fresh cache is ready without a request")
        let updated = expectation(description: "expired cache is refreshed")
        hooks.addOnReady { [weak service] _ in
            XCTAssertTrue(engine.requests.isEmpty)
            XCTAssertEqual("cached", service?.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
            ready.fulfill()
        }
        hooks.addOnConfigChanged { [weak service] config, _ in
            guard config.settings["fakeKey"]?.value.stringValue == "updated" else { return }
            service?.close()
            updated.fulfill()
        }
        service.start()
        wait(for: [ready, updated], timeout: 25, enforceOrder: true)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    func testPollsWhenCacheExpired() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test1"), statusCode: 200))

        let initValue = String(format: testJsonFormat, "test").asEntryString(date: Date().addingTimeInterval(-3600))
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 30)
        let hooks = Hooks()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
        let cachedHookStarted = DispatchSemaphore(value: 0)
        let releaseCachedHook = DispatchSemaphore(value: 0)
        defer {
            releaseCachedHook.signal()
            service.close()
        }
        let fetched = expectation(description: "poll fetches expired cache")
        fetched.assertForOverFulfill = false
        hooks.addOnConfigChanged { config, _ in
            switch config.settings["fakeKey"]?.value.stringValue {
            case "test":
                cachedHookStarted.signal()
                XCTAssertEqual(.success, releaseCachedHook.wait(timeout: .now() + 30))
            case "test1":
                fetched.fulfill()
            default:
                XCTFail("Unexpected config")
            }
        }
        let settings = expectation(description: "settings returns fetched config")
        DispatchQueue.global().async {
            service.settings { result in
                XCTAssertEqual("test1", result.settings["fakeKey"]?.value.stringValue)
                settings.fulfill()
            }
        }
        guard cachedHookStarted.wait(timeout: .now() + 5) == .success else {
            XCTFail("Cached config hook did not start")
            return
        }
        service.start()
        wait(for: [fetched], timeout: 10)
        releaseCachedHook.signal()
        wait(for: [settings], timeout: 10)
        XCTAssertEqual(1, engine.requests.count)
    }

    func testOnlineOffline() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        Thread.sleep(forTimeInterval: 1.5)

        service.setOffline()
        XCTAssertTrue(service.isOffline)
        XCTAssertEqual(2, engine.requests.count)

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(2, engine.requests.count)
        service.setOnline()
        XCTAssertFalse(service.isOffline)

        waitFor {
            engine.requests.count >= 3
        }
    }

    func testInitOffline() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true).ensureStarted()

        XCTAssertTrue(service.isOffline)
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(0, engine.requests.count)

        service.setOnline()

        XCTAssertFalse(service.isOffline)
        waitFor {
            engine.requests.count >= 2
        }
    }

    func testInitWaitTimeIgnoredWhenCacheIsNotExpired() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds < 1)
    }

    func testCacheIsNotExpiredCallsOnReady() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let readyExpectation = expectation(description: "wait for ready")
        let hooks = Hooks()
        hooks.addOnReady { snapshot in
            readyExpectation.fulfill()
            XCTAssertEqual(ClientCacheState.hasUpToDateFlagData, snapshot.cacheState)
        }
        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false).ensureStarted()

        let settingsExpectation = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            settingsExpectation.fulfill()
        }
        wait(for: [settingsExpectation, readyExpectation], timeout: 5)
        XCTAssertTrue(engine.requests.isEmpty)
    }

    func testInitWaitTimeReturnCached() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let initValue = String(format: testJsonFormat, "test").asEntryString(date: Date().subtract(months: 1)!)
        let cache = SingleValueCache(initValue: initValue)
        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()

        let settingsExpectation = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value.stringValue)
            settingsExpectation.fulfill()
        }
        wait(for: [settingsExpectation], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }
}
