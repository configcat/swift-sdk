import XCTest
@testable import ConfigCat

class LazyLoadingAsyncTests: XCTestCase {
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
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 5, useAsyncRefresh: true)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for cache invalidation
        sleep(6)

        //previous value returned until the new is not fetched
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for refresh response
        sleep(3)

        //new value is present
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testGetFailedRefresh() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 500, delay: 2))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 5, useAsyncRefresh: true)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for cache invalidation
        sleep(6)

        //previous value returned until the new is not fetched
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)

        //wait for refresh response
        sleep(1)

        //new value is present
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }
}
