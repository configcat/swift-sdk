import XCTest
@testable import ConfigCat

class ManualPollingTests: XCTestCase {
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
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))

        policy.refresh().wait()
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        policy.refresh().wait()
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testGetFailedRefresh() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 500))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))
        policy.refresh().wait()
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        policy.refresh().wait()
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testCacheFails() throws {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "test2"), statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: ""))
        policy.refresh().wait()
        XCTAssertEqual("test", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
        policy.refresh().wait()
        XCTAssertEqual("test2", (try policy.getConfiguration().get().entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }
}
