import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    private var mockSession = MockURLSession()
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testGet() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        
        sleep(3)
        
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }
    
    func testGetFailedRequest() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 500))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(),dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))
        
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        
        sleep(3)
        
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testOnConfigChanged() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))
        
        var called = false
        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2, onConfigChanged: { () in
            called = true
        })
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))
        
        sleep(1)
        
        XCTAssertTrue(called)
        
        sleep(3)
        
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testRequestTimeout() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200, delay: 3))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        sleep(2)

        XCTAssertEqual(1, mockSession.requests.count)

        sleep(2)

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testInitWaitTimeTimeout() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200, delay: 5))

        let start = Date()
        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))
        XCTAssertTrue(try policy.getConfiguration().get().entries.isEmpty)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        print(elapsedTimeInSeconds)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: mockCache, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: self.testJsonFormat, "test"), mockCache.store.values.first)

        sleep(3)

        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: self.testJsonFormat, "test2"), mockCache.store.values.first)
    }

    func testCacheFails() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: FailingCache(), logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        sleep(3)

        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

}
