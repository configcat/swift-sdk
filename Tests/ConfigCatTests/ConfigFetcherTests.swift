import XCTest
@testable import ConfigCat

class ConfigFetcherTests: XCTestCase {
    func testFetchFailsWithInvalidUrl() {
        for baseUrl in ["https://[", "https://example.com:bad", "https://exa mple.com"] {
            let engine = MockEngine(autoRespond: false)
            let hooks = Hooks()
            let expectedMessage = "Unexpected error occurred while trying to fetch config JSON. The configuration URL is invalid."
            let errorReported = expectation(description: "invalid URL reported")
            errorReported.assertForOverFulfill = true
            hooks.addOnError { error in
                XCTAssertEqual(expectedMessage, error)
                errorReported.fulfill()
            }
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
                XCTAssertEqual(expectedMessage, message)
                expectation.fulfill()
            }
            wait(for: [expectation, errorReported], timeout: 5)
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
            let expectedMessage = "Unexpected error occurred while trying to fetch config JSON. The network request did not return an HTTP response."
            let errorReported = expectation(description: "invalid response reported")
            errorReported.assertForOverFulfill = true
            hooks.addOnError { error in
                XCTAssertEqual(expectedMessage, error)
                errorReported.fulfill()
            }
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
                XCTAssertEqual(expectedMessage, message)
                expectation.fulfill()
            }
            wait(for: [expectation, errorReported], timeout: 5)
        }
    }

    func testFetchFailsWithMissingOrEmptyBody() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let responses = [Response(response: response), Response(body: "", statusCode: 200)]

        for response in responses {
            let engine = MockEngine()
            engine.enqueueResponse(response: response)
            let hooks = Hooks()
            let hookErrors = Locked<[String]>([])
            hooks.addOnError { error in hookErrors.withLock { $0.append(error) } }
            let recordingLogger = RecordingLogger()
            let logger = InternalLogger(log: recordingLogger, level: .warning, hooks: hooks)
            let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: "", mode: "m", dataGovernance: .global)
            let expectation = self.expectation(description: "invalid content completes")
            expectation.assertForOverFulfill = true

            fetcher.fetch(eTag: "") { result in
                guard case .failure(let message, let errorCode, let isTransient) = result else {
                    XCTFail("Expected an invalid content failure")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(errorCode, .invalidHttpResponseContent)
                XCTAssertTrue(isTransient)
                XCTAssertTrue(message.contains("HTTP response content was invalid"))
                XCTAssertEqual(hookErrors.withLock { $0 }, [message])
                XCTAssertEqual(recordingLogger.logs, ["ERROR [1105] \(message)"])
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
        let sdkKey = "configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012"
        let maskedKey = "***************/**********************/****************789012"
        for statusCode in [403, 404] {
            let engine = MockEngine()
            engine.enqueueResponse(response: Response(body: "", statusCode: statusCode))
            let hooks = Hooks()
            let expectedMessage = "Your SDK Key seems to be wrong: '\(maskedKey)'. You can find the valid SDK Key at https://app.configcat.com/sdkkey. Status code: \(statusCode)"
            let errorReported = expectation(description: "invalid SDK key reported")
            errorReported.assertForOverFulfill = true
            hooks.addOnError { error in
                XCTAssertEqual(expectedMessage, error)
                errorReported.fulfill()
            }
            let recordingLogger = RecordingLogger()
            let logger = InternalLogger(log: recordingLogger, level: .warning, hooks: hooks)
            let fetcher = ConfigFetcher(httpEngine: engine, logger: logger, sdkKey: sdkKey, mode: "m", dataGovernance: .global)
            let expectation = self.expectation(description: "HTTP \(statusCode) completes")

            fetcher.fetch(eTag: "") { response in
                guard case .failure(let message, let errorCode, let isTransient) = response else {
                    XCTFail("Expected an invalid SDK key failure")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(message, expectedMessage)
                XCTAssertEqual(errorCode, .invalidSdkKey)
                XCTAssertFalse(isTransient)
                XCTAssertEqual(recordingLogger.logs, ["ERROR [1100] \(expectedMessage)"])
                expectation.fulfill()
            }
            wait(for: [expectation, errorReported], timeout: 5)
        }
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
