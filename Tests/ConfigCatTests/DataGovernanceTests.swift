import XCTest
@testable import ConfigCat

class DataGovernanceTests: XCTestCase {
    private let jsonTemplate: String = #"{ "p": { "u": "%@", "r": %@ }, "f": {} }"#
    private let customCdnUrl: String = "https://custom-cdn.configcat.com"

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testShouldStayOnServer() throws {
        // Arrange
        let body = String(format: jsonTemplate, "https://fakeUrl", "0")
        MockHTTP.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(1, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrl() throws {
        // Arrange
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        MockHTTP.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(1, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrlEvenWithForce() throws {
        // Arrange
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        MockHTTP.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(1, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServer() throws {
        // Arrange
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "1")
        let secondBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "0")
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(2, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServerWhenForced() throws {
        // Arrange
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "0")
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(2, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoop() throws {
        // Arrange
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "1")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(3, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[2].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoopWhenForced() throws {
        // Arrange
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = createFetcher()

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(3, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[2].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldRespectCustomUrlWhenNotForced() throws {
        // Arrange
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        MockHTTP.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher(url: customCdnUrl)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(1, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests.last?.url?.absoluteString.starts(with: customCdnUrl) ?? false)
    }

    func testShouldNotRespectCustomUrlWhenForced() throws {
        // Arrange
        let firstBody = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "0")
        MockHTTP.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher(url: customCdnUrl)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        // Assert
        XCTAssertEqual(2, MockHTTP.requests.count)
        XCTAssertTrue(MockHTTP.requests[0].url?.absoluteString.starts(with: customCdnUrl) ?? false)
        XCTAssertTrue(MockHTTP.requests[1].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    private func createFetcher(url: String = "") -> ConfigFetcher {
        ConfigFetcher(session: MockHTTP.session(),
                logger: Logger.noLogger,
                sdkKey: "",
                mode: "",
                dataGovernance: DataGovernance.global,
                baseUrl: url)
    }
}
