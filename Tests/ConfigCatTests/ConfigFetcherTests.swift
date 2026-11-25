import XCTest
@testable import ConfigCat

class ConfigFetcherTests: XCTestCase {
    func testFetchFailsWithInvalidUrl() {
        for baseUrl in ["https://[", "https://example.com:bad", "https://exa mple.com"] {
            let engine = MockEngine(autoRespond: false)
            let hooks = Hooks()
            var loggedErrors = [String]()
            hooks.addOnError { loggedErrors.append($0) }
            let logger = InternalLogger(log: NoLogger(), level: .nolog, hooks: hooks)
            let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: "", mode: "m", dataGovernance: .global, baseUrl: baseUrl)
            let expectation = self.expectation(description: "invalid URL completes")
            expectation.assertForOverFulfill = true

            fetcher.fetch(eTag: "") { result in
                guard case .failure(let message, let errorCode, let isTransient) = result else {
                    XCTFail("Expected a fetch failure for \(baseUrl)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(errorCode, .httpRequestFailure)
                XCTAssertTrue(isTransient)
                XCTAssertTrue(message.contains("configuration URL is invalid"))
                XCTAssertEqual(loggedErrors, [message])
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5)
            XCTAssertTrue(engine.requests.isEmpty)
        }
    }

    func testFetchFailsWithoutHttpResponse() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let responses: [URLResponse?] = [
            nil,
            URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        ]

        for response in responses {
            let engine = MockEngine()
            engine.enqueueResponse(response: Response(response: response))
            let hooks = Hooks()
            var loggedErrors = [String]()
            hooks.addOnError { loggedErrors.append($0) }
            let logger = InternalLogger(log: NoLogger(), level: .nolog, hooks: hooks)
            let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: "", mode: "m", dataGovernance: .global)
            let expectation = self.expectation(description: "invalid response completes")
            expectation.assertForOverFulfill = true

            fetcher.fetch(eTag: "") { result in
                guard case .failure(let message, let errorCode, let isTransient) = result else {
                    XCTFail("Expected a fetch failure")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(errorCode, .httpRequestFailure)
                XCTAssertTrue(isTransient)
                XCTAssertTrue(message.contains("did not return an HTTP response"))
                XCTAssertEqual(loggedErrors, [message])
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5)
        }
    }

    func testSimpleFetchSuccess() throws {
        let engine = MockEngine()
        let testBody = #"{ "f": { "fakeKey": { "v": { "s": "fakeValue" }, "t":1 } } }"#
        engine.enqueueResponse(response: Response(body: testBody, statusCode: 200))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertEqual("fakeValue", response.entry?.config.settings["fakeKey"]?.value.stringValue)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testSimpleFetchNotModified() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 304))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.notModified, response)
            XCTAssertNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testSimpleFetchFailed() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "", statusCode: 404))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.failure(message: "", errorCode: RefreshErrorCode.invalidSdkKey ,isTransient: false), response)
            XCTAssertNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testFetchNotModifiedEtag() throws {
        let engine = MockEngine()
        let etag = "test"
        let testBody = #"{ "f": { "fakeKey": { "v": { "s": "fakeValue" }, "t":1 } } }"#
        engine.enqueueResponse(response: Response(body: testBody, statusCode: 200, headers: ["Etag": etag]))
        engine.enqueueResponse(response: Response(body: "", statusCode: 304))

        let fetcher = ConfigFetcher(httpEngine: engine, logger: InternalLogger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        let expectation = self.expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            XCTAssertEqual(etag, response.entry?.eTag)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let notModifiedExpectation = self.expectation(description: "wait for response")
        fetcher.fetch(eTag: etag) { response in
            XCTAssertEqual(.notModified, response)
            XCTAssertNil(response.entry)
            notModifiedExpectation.fulfill()
        }
        wait(for: [notModifiedExpectation], timeout: 5)
        XCTAssertEqual(etag, engine.requests.last?.value(forHTTPHeaderField: "If-None-Match"))
    }
}
