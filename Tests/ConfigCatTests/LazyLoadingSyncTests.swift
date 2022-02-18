import XCTest
@testable import ConfigCat

class LazyLoadingSyncTests: XCTestCase {
    private var mockSession = MockURLSession()
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testGet() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200, delay: 2))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for cache invalidation
        sleep(3)

        //next call will block until the new value is fetched
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testGetFailedRefresh() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 500))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for cache invalidation
        sleep(3)

        //next call will block until the new value is fetched
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: mockCache, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: self.testJsonFormat, "test"), mockCache.store.values.first)

        //wait for cache invalidation
        sleep(3)

        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertEqual(String(format: self.testJsonFormat, "test2"), mockCache.store.values.first)
    }

    func testCacheFails() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: FailingCache(), logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for cache invalidation
        sleep(3)

        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }
}
