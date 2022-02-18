import XCTest
@testable import ConfigCat

class DataGovernanceTests: XCTestCase {
    private let jsonTemplate: String = #"{ "p": { "u": "%@", "r": %@ }, "f": {} }"#
    private let customCdnUrl: String = "https://custom-cdn.configcat.com"
    private var mockSession = MockURLSession()

    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testShouldStayOnServer() throws {
        // Arrange
        let body = String(format: self.jsonTemplate, "https://fakeUrl", "0")
        self.mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(1, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests.last?.url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrl() throws {
        // Arrange
        let body = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "1")
        self.mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(1, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests.last?.url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrlEvenWithForce() throws {
        // Arrange
        let body = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "2")
        self.mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(1, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests.last?.url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServer() throws {
        // Arrange
        let firstBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "1")
        let secondBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "0")
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(2, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests[0].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[1].url?.absoluteString.starts(with: ConfigFetcher.euOnlyBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServerWhenForced() throws {
        // Arrange
        let firstBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "2")
        let secondBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "0")
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(2, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests[0].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[1].url?.absoluteString.starts(with: ConfigFetcher.euOnlyBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoop() throws {
        // Arrange
        let firstBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "1")
        let secondBody = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "1")
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(3, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests[0].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[1].url?.absoluteString.starts(with: ConfigFetcher.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[2].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoopWhenForced() throws {
        // Arrange
        let firstBody = String(format: self.jsonTemplate, ConfigFetcher.euOnlyBaseUrl, "2")
        let secondBody = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "2")
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = self.createfetcher()

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(3, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests[0].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[1].url?.absoluteString.starts(with: ConfigFetcher.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[2].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    func testShouldRespectCustomUrlWhenNotForced() throws {
        // Arrange
        let body = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "1")
        self.mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = self.createfetcher(url: self.customCdnUrl)

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(1, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests.last?.url?.absoluteString.starts(with: self.customCdnUrl) ?? false)
    }

    func testShouldNotRespectCustomUrlWhenForced() throws {
        // Arrange
        let firstBody = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "2")
        let secondBody = String(format: self.jsonTemplate, ConfigFetcher.globalBaseUrl, "0")
        self.mockSession.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        self.mockSession.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = self.createfetcher(url: self.customCdnUrl)

        // Act
        _ = try fetcher.getConfiguration().get()

        // Assert
        XCTAssertEqual(2, self.mockSession.requests.count)
        XCTAssertTrue(self.mockSession.requests[0].url?.absoluteString.starts(with: self.customCdnUrl) ?? false)
        XCTAssertTrue(self.mockSession.requests[1].url?.absoluteString.starts(with: ConfigFetcher.globalBaseUrl) ?? false)
    }

    private func createfetcher(url: String = "") -> ConfigFetcher {
        let configJsonCache = ConfigJsonCache(logger: Logger.noLogger)
        return ConfigFetcher(session: self.mockSession,
                             logger: Logger.noLogger,
                             configJsonCache: configJsonCache,
                             sdkKey: "",
                             mode: "",
                             dataGovernance: DataGovernance.global,
                             baseUrl: url)
    }
}
