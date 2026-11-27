import XCTest
@testable import ConfigCat

class ConfigServiceTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#

    func testLockedValueSupportsConcurrentUpdates() {
        let value = Locked(0)
        DispatchQueue.concurrentPerform(iterations: 1_000) { _ in
            value.withLock { $0 += 1 }
        }
        XCTAssertEqual(value.withLock { $0 }, 1_000)
    }

    func testLockedValueUnlocksAfterThrowing() {
        enum TestError: Error { case expected }
        let value = Locked(1)

        XCTAssertThrowsError(try value.withLock { value in
            value += 1
            throw TestError.expected
        })
        XCTAssertEqual(value.withLock { $0 }, 2)
    }

    func testEmptySentinelsAreDistinctFromEmptyConfigData() throws {
        XCTAssertTrue(ConfigEntry.empty.isEmpty)
        let emptyConfig = try ConfigEntry.fromConfigJson(json: #"{"f":{}}"#, eTag: "", fetchTime: .distantPast).get()
        XCTAssertFalse(emptyConfig.isEmpty)
        XCTAssertFalse(ConfigEntry.empty.withFetchTime(time: .distantPast).isEmpty)

        XCTAssertTrue(SettingsResult.empty.isEmpty)
        XCTAssertFalse(SettingsResult(settings: [:], fetchTime: .distantPast).isEmpty)
    }

    func testSlowCacheReadCannotOverwriteNewHttpEntry() throws {
        let initialEntry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "initial"), eTag: "initial", fetchTime: Date()
        ).get()
        let staleEntry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "stale"), eTag: "stale", fetchTime: Date().addingTimeInterval(-60)
        ).get()
        let cache = BlockingCache(initialValue: initialEntry.cacheString)
        cache.staleValue = staleEntry.cacheString
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()
        defer { service.close() }

        let settingsCompleted = expectation(description: "settings completed with fresh entry")
        DispatchQueue.global().async {
            service.settings { result in
                XCTAssertEqual("fresh", result.settings["fakeKey"]?.value.stringValue)
                settingsCompleted.fulfill()
            }
        }
        XCTAssertEqual(.success, cache.blockedReadStarted.wait(timeout: .now() + 5))

        let refreshCompleted = expectation(description: "HTTP refresh completed")
        service.refresh { result in
            XCTAssertTrue(result.success)
            refreshCompleted.fulfill()
        }
        XCTAssertEqual(1, engine.requests.count)
        let freshJson = String(format: testJsonFormat, "fresh")
        engine.respond(Response(body: freshJson, statusCode: 200, headers: ["Etag": "fresh"]))
        wait(for: [refreshCompleted], timeout: 5)

        cache.releaseBlockedRead.signal()
        wait(for: [settingsCompleted], timeout: 5)
        XCTAssertEqual("fresh", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
        XCTAssertTrue(cache.stored.contains("fresh"))
    }

    func testCacheReadDuringHttpCacheWriteCannotOverwriteNewEntry() throws {
        let initialEntry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "initial"), eTag: "initial", fetchTime: Date()
        ).get()
        let staleEntry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "stale"), eTag: "stale", fetchTime: Date().addingTimeInterval(-60)
        ).get()
        let cache = BlockingCache(initialValue: initialEntry.cacheString)
        cache.staleValue = staleEntry.cacheString
        cache.staleReadNumber = 3
        cache.blockStaleRead = false
        cache.blockWrite = true
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()
        defer { service.close() }

        let refreshed = expectation(description: "HTTP refresh completed")
        service.refresh { result in
            XCTAssertTrue(result.success)
            refreshed.fulfill()
        }
        let freshJson = String(format: testJsonFormat, "fresh")
        DispatchQueue.global().async {
            engine.respond(Response(body: freshJson, statusCode: 200, headers: ["Etag": "fresh"]))
        }
        XCTAssertEqual(.success, cache.blockedWriteStarted.wait(timeout: .now() + 5))

        let settingsRead = expectation(description: "settings retain the fresh HTTP entry")
        service.settings { result in
            XCTAssertEqual("fresh", result.settings["fakeKey"]?.value.stringValue)
            settingsRead.fulfill()
        }

        cache.releaseBlockedWrite.signal()
        wait(for: [settingsRead, refreshed], timeout: 5)
        XCTAssertEqual("fresh", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
    }

    func testRefreshAfterInitializationTimeoutJoinsActiveFetch() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()
        defer { service.close() }
        let timedOut = expectation(description: "initial settings released on timeout")
        service.settings { result in
            XCTAssertTrue(result.isEmpty)
            timedOut.fulfill()
        }
        wait(for: [timedOut], timeout: 5)
        XCTAssertEqual(1, engine.requests.count)

        let refreshed = expectation(description: "refresh receives active request result")
        service.refresh { result in
            XCTAssertTrue(result.success)
            XCTAssertEqual("test", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
            refreshed.fulfill()
        }
        XCTAssertEqual(1, engine.requests.count)
        engine.respond(Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        wait(for: [refreshed], timeout: 5)
        engine.respond(Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
    }

    func testHookRefreshWaitsForItsOwnResponse() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let hooks = Hooks()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false).ensureStarted()
        defer { service.close() }
        let second = expectation(description: "hook refresh receives second response")
        second.assertForOverFulfill = true
        hooks.addOnConfigChanged(handler: { config, _ in
            guard config.settings["fakeKey"]?.value.stringValue == "first" else { return }
            service.refresh { result in
                XCTAssertTrue(result.success)
                XCTAssertEqual("second", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
                second.fulfill()
            }
        })
        let first = expectation(description: "first refresh completed")
        service.refresh { _ in first.fulfill() }

        engine.respond(Response(body: String(format: testJsonFormat, "first"), statusCode: 200))
        wait(for: [first], timeout: 5)
        XCTAssertEqual(2, engine.requests.count)
        engine.respond(Response(body: String(format: testJsonFormat, "second"), statusCode: 200))
        wait(for: [second], timeout: 5)
    }

    func testRefreshCompletionCanStartAnotherRefresh() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()
        defer { service.close() }
        let second = expectation(description: "nested refresh receives second response")
        service.refresh { first in
            XCTAssertTrue(first.success)
            service.refresh { result in
                XCTAssertTrue(result.success)
                XCTAssertEqual("second", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
                second.fulfill()
            }
        }

        engine.respond(Response(body: String(format: testJsonFormat, "first"), statusCode: 200))
        XCTAssertEqual(2, engine.requests.count)
        engine.respond(Response(body: String(format: testJsonFormat, "second"), statusCode: 200))
        wait(for: [second], timeout: 5)
    }

    func testCloseCompletesPendingRefreshOnceAndPreventsNewFetch() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false).ensureStarted()
        let pending = expectation(description: "pending refresh completed on close")
        pending.assertForOverFulfill = true
        service.refresh { _ in pending.fulfill() }
        service.close()

        let afterClose = expectation(description: "refresh after close completes without HTTP")
        service.refresh { _ in afterClose.fulfill() }
        XCTAssertEqual(1, engine.requests.count)
        engine.respond(Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        wait(for: [pending, afterClose], timeout: 5)
        engine.respond(Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
    }

    func testResponsesAfterCloseDoNotChangeCacheOrNotify() throws {
        let initialEntry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "initial"), eTag: "initial", fetchTime: Date().addingTimeInterval(-60)
        ).get()

        for statusCode in [200, 304, 403] {
            let cache = SingleValueCache(initValue: initialEntry.cacheString)
            let engine = MockEngine(autoRespond: false)
            let mode = PollingModes.manualPoll()
            let hooks = Hooks()
            let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
            let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false).ensureStarted()
            let initialMemory = service.inMemory.entry.cacheString
            let initialCache = try cache.read(for: "")
            XCTAssertEqual("initial", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
            let completionCount = Locked(0)
            service.refresh { _ in completionCount.withLock { $0 += 1 } }
            XCTAssertEqual(1, engine.requests.count, "HTTP \(statusCode)")

            service.close()
            XCTAssertEqual(1, completionCount.withLock { $0 }, "HTTP \(statusCode)")
            hooks.addOnConfigChanged(handler: { _, _ in
                XCTFail("HTTP \(statusCode) notified config changed after close")
            })
            engine.respond(Response(body: String(format: testJsonFormat, "new"), statusCode: statusCode))

            XCTAssertEqual(initialMemory, service.inMemory.entry.cacheString, "HTTP \(statusCode)")
            XCTAssertEqual(initialCache, try cache.read(for: ""), "HTTP \(statusCode)")
            XCTAssertEqual(1, completionCount.withLock { $0 }, "HTTP \(statusCode)")
        }
    }

    func testCloseDuringStartupCacheReadDoesNotApplyEntryOrNotify() throws {
        let entry = try ConfigEntry.fromConfigJson(
            json: String(format: testJsonFormat, "cached"), eTag: "", fetchTime: Date()
        ).get()
        let cache = BlockingCache(initialValue: "")
        cache.staleReadNumber = 1
        cache.staleValue = entry.cacheString
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let hooks = Hooks()
        let ready = expectation(description: "ready is not reported after close")
        ready.isInverted = true
        let changed = expectation(description: "config changed is not reported after close")
        changed.isInverted = true
        hooks.addOnReady(handler: { _ in ready.fulfill() })
        hooks.addOnConfigChanged(handler: { _, _ in changed.fulfill() })
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
        let finished = expectation(description: "startup finishes")
        DispatchQueue.global().async {
            service.start()
            finished.fulfill()
        }
        XCTAssertEqual(.success, cache.blockedReadStarted.wait(timeout: .now() + 5))
        service.close()
        cache.releaseBlockedRead.signal()
        wait(for: [finished], timeout: 5)
        wait(for: [ready, changed], timeout: 0.1)
        XCTAssertTrue(service.inMemory.entry.isEmpty)
        XCTAssertTrue(engine.requests.isEmpty)
    }

    func testReadyHooksAreCapturedBeforeWaitersCloseService() {
        for mode in [PollingModes.manualPoll(), PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)] {
            let engine = MockEngine(autoRespond: false)
            let hooks = Hooks()
            let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
            let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
            let ready = expectation(description: "captured ready hook runs")
            let snapshotReady = expectation(description: "captured snapshot hook runs")
            let waiter = expectation(description: "ready waiter runs once")
            waiter.assertForOverFulfill = true
            hooks.addOnReady(handler: { snapshot in
                XCTAssertEqual(.noFlagData, snapshot.cacheState)
                ready.fulfill()
            })
            hooks.addOnReady(handler: { _ in snapshotReady.fulfill() })
            service.waitForReady { state in
                XCTAssertEqual(.noFlagData, state)
                service.close()
                hooks.clear()
                waiter.fulfill()
            }
            service.start()
            wait(for: [waiter, ready, snapshotReady], timeout: 5)
        }
    }

    func testCloseBeforeReadyUnblocksWaiterAndSuppressesLateResponseReady() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let hooks = Hooks()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
        let waiter = expectation(description: "ready waiter completes on close")
        waiter.assertForOverFulfill = true
        let ready = expectation(description: "ready is not reported after close")
        ready.isInverted = true
        hooks.addOnReady(handler: { _ in ready.fulfill() })
        service.waitForReady { state in
            XCTAssertEqual(.noFlagData, state)
            waiter.fulfill()
        }
        service.refresh { _ in }
        XCTAssertEqual(1, engine.requests.count)
        service.close()
        let lateWaiter = expectation(description: "late waiter completes")
        service.waitForReady { state in
            XCTAssertEqual(.noFlagData, state)
            lateWaiter.fulfill()
        }
        engine.respond(Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        wait(for: [waiter, lateWaiter, ready], timeout: 0.1)
    }

    func testOnlineBeforeStartDoesNotPollUntilStarted() {
        let cache = ObservingCache()
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60)
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true)
        defer { service.close() }
        service.setOnline()
        XCTAssertEqual(.timedOut, cache.readStarted.wait(timeout: .now() + 0.2))
        service.start()
        XCTAssertEqual(.success, cache.readStarted.wait(timeout: .now() + 5))
    }

    func testCloseBeforeStartDoesNotReadCacheOrPoll() {
        for mode in [PollingModes.manualPoll(), PollingModes.autoPoll()] {
            let cache = ObservingCache()
            let engine = MockEngine(autoRespond: false)
            let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
            let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
            service.close()
            service.start()
            XCTAssertEqual(.timedOut, cache.readStarted.wait(timeout: .now() + 0.1))
            XCTAssertTrue(engine.requests.isEmpty)
        }
    }

    func testManualSettingsBeforeStartDoesNotFetch() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
        defer { service.close() }
        let completed = expectation(description: "manual settings completes without fetch")
        service.settings { result in
            XCTAssertTrue(result.isEmpty)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
        XCTAssertTrue(engine.requests.isEmpty)
    }
}
