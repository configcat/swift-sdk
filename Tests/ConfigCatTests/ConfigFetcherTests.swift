import XCTest
@testable import ConfigCat

class ConfigFetcherTests: XCTestCase {
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
            XCTAssertEqual(.failure(message: "", isTransient: false), response)
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
