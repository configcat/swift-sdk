import XCTest
@testable import ConfigCat

class DataGovernanceTests: XCTestCase {
    private let jsonTemplate: String = #"{ "p": { "u": "%@", "r": %@ }, "f": {} }"#
    private let customCdnUrl: String = "https://custom-cdn.configcat.com"

    func testShouldStayOnServer() throws {
        // Arrange
        let engine = MockEngine()
        let body = String(format: jsonTemplate, "https://fakeUrl", "0")
        engine.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(1, engine.requests.count)
        XCTAssertTrue(engine.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrl() throws {
        // Arrange
        let engine = MockEngine()
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        engine.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(1, engine.requests.count)
        XCTAssertTrue(engine.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldStayOnSameUrlEvenWithForce() throws {
        // Arrange
        let engine = MockEngine()
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        engine.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(1, engine.requests.count)
        XCTAssertTrue(engine.requests.last?.url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServer() throws {
        // Arrange
        let engine = MockEngine()
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "1")
        let secondBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "0")
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(2, engine.requests.count)
        XCTAssertTrue(engine.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
    }

    func testShouldRedirectToAnotherServerWhenForced() throws {
        // Arrange
        let engine = MockEngine()
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "0")
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(2, engine.requests.count)
        XCTAssertTrue(engine.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoop() throws {
        // Arrange
        let engine = MockEngine()
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "1")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(3, engine.requests.count)
        XCTAssertTrue(engine.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[2].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldBreakRedirectLoopWhenForced() throws {
        // Arrange
        let engine = MockEngine()
        let firstBody = String(format: jsonTemplate, Constants.euOnlyBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        let fetcher = createFetcher(http: engine)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(3, engine.requests.count)
        XCTAssertTrue(engine.requests[0].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[1].url?.absoluteString.starts(with: Constants.euOnlyBaseUrl) ?? false)
        XCTAssertTrue(engine.requests[2].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    func testShouldRespectCustomUrlWhenNotForced() throws {
        // Arrange
        let engine = MockEngine()
        let body = String(format: jsonTemplate, Constants.globalBaseUrl, "1")
        engine.enqueueResponse(response: Response(body: body, statusCode: 200))
        let fetcher = createFetcher(http: engine, url: customCdnUrl)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(1, engine.requests.count)
        XCTAssertTrue(engine.requests.last?.url?.absoluteString.starts(with: customCdnUrl) ?? false)
    }

    func testShouldNotRespectCustomUrlWhenForced() throws {
        // Arrange
        let engine = MockEngine()
        let firstBody = String(format: jsonTemplate, Constants.globalBaseUrl, "2")
        let secondBody = String(format: jsonTemplate, Constants.globalBaseUrl, "0")
        engine.enqueueResponse(response: Response(body: firstBody, statusCode: 200))
        engine.enqueueResponse(response: Response(body: secondBody, statusCode: 200))
        let fetcher = createFetcher(http: engine, url: customCdnUrl)

        // Act
        let expectation = expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Assert
        XCTAssertEqual(2, engine.requests.count)
        XCTAssertTrue(engine.requests[0].url?.absoluteString.starts(with: customCdnUrl) ?? false)
        XCTAssertTrue(engine.requests[1].url?.absoluteString.starts(with: Constants.globalBaseUrl) ?? false)
    }

    private func createFetcher(http: HttpEngine, url: String = "") -> ConfigFetcher {
        ConfigFetcher(httpEngine: http,
                logger: Logger.noLogger,
                sdkKey: "",
                mode: "",
                dataGovernance: DataGovernance.global,
                baseUrl: url)
    }
}
