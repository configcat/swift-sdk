import XCTest
@testable import ConfigCat

class ConfigFetcherTests: XCTestCase {
    private var mockSession = MockURLSession()

    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testSimpleFetchSuccess() throws {
        let testBody = #"{ "f": { "fakeKey": { "v": "fakeValue", "p": [], "r": [] } } }"#
        mockSession.enqueueResponse(response: Response(body: testBody, statusCode: 200))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        XCTAssertEqual("fakeValue", (try fetcher.getConfiguration().get().config?.entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
    }

    func testSimpleFetchNotModified() throws {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 304))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        let response = try fetcher.getConfiguration().get()
        XCTAssertTrue(response.isNotModified())
        XCTAssertNil(response.config)
    }

    func testSimpleFetchFailed() throws {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 404))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        let response = try fetcher.getConfiguration().get()
        XCTAssertTrue(response.isFailed())
        XCTAssertNil(response.config)
    }

    func testFetchNotModifiedEtag() throws {
        let etag = "test"
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 200, headers: ["Etag": etag]))
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 304))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        var response = try fetcher.getConfiguration().get()
        XCTAssertTrue(response.isFetched())
        response = try fetcher.getConfiguration().get()
        XCTAssertTrue(response.isNotModified())

        XCTAssertEqual(etag, mockSession.requests.last?.value(forHTTPHeaderField: "If-None-Match"))
    }

    func testOngoingFetch() throws {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 200, delay: 1))

        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, configJsonCache: configJsonCache, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        var asyncResponse = fetcher.getConfiguration()
        var isFetching = try fetcher.isFetching()
        XCTAssertTrue(isFetching)

        var response = try asyncResponse.get()
        isFetching = try fetcher.isFetching()
        XCTAssertFalse(isFetching)
    }
}
