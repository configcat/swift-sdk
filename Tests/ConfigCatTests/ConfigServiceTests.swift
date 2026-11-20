import XCTest
@testable import ConfigCat

class ConfigServiceTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 1, "v": { "s": "%@" } } } }"#

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
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
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
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
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
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
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
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)
        defer { service.close() }
        var subscribed = false
        var secondCompleted = false
        let second = expectation(description: "hook refresh receives second response")
        hooks.addOnConfigChanged(snapshotHandler: { _, _ in
            guard !subscribed else { return }
            subscribed = true
            service.refresh { result in
                XCTAssertTrue(result.success)
                XCTAssertEqual("second", service.inMemory.entry.config.settings["fakeKey"]?.value.stringValue)
                secondCompleted = true
                second.fulfill()
            }
        })
        let first = expectation(description: "first refresh completed")
        service.refresh { _ in first.fulfill() }

        engine.respond(Response(body: String(format: testJsonFormat, "first"), statusCode: 200))
        wait(for: [first], timeout: 5)
        XCTAssertFalse(secondCompleted)
        XCTAssertEqual(2, engine.requests.count)
        engine.respond(Response(body: String(format: testJsonFormat, "second"), statusCode: 200))
        wait(for: [second], timeout: 5)
    }

    func testRefreshCompletionCanStartAnotherRefresh() {
        let engine = MockEngine(autoRespond: false)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
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
        let service = ConfigService(snapshotBuilder: EmptySnapshotBuilder(), log: InternalLogger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)
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
}