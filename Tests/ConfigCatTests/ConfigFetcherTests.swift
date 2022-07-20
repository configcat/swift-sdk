import XCTest
@testable import ConfigCat

class ConfigFetcherTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testSimpleFetchSuccess() throws {
        let testBody = #"{ "f": { "fakeKey": { "v": "fakeValue", "p": [], "r": [] } } }"#
        MockHTTP.enqueueResponse(response: Response(body: testBody, statusCode: 200))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertEqual("fakeValue", (response.entry?.config.entries["fakeKey"] as? [String: Any])?[Config.value] as? String)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testSimpleFetchNotModified() throws {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 304))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.notModified, response)
            XCTAssertNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testSimpleFetchFailed() throws {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 404))

        let expectation = self.expectation(description: "wait for response")
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.failure, response)
            XCTAssertNil(response.entry)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testFetchNotModifiedEtag() throws {
        let etag = "test"
        let testBody = #"{ "f": { "fakeKey": { "v": "fakeValue", "p": [], "r": [] } } }"#
        MockHTTP.enqueueResponse(response: Response(body: testBody, statusCode: 200, headers: ["Etag": etag]))
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 304))

        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: "m", dataGovernance: DataGovernance.global)
        let expectation = self.expectation(description: "wait for response")
        fetcher.fetch(eTag: "") { response in
            XCTAssertEqual(.fetched(.empty), response)
            XCTAssertNotNil(response.entry)
            XCTAssertEqual(etag, response.entry?.eTag)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        let notModifiedExpectation = self.expectation(description: "wait for response")
        fetcher.fetch(eTag: etag) { response in
            XCTAssertEqual(.notModified, response)
            XCTAssertNil(response.entry)
            notModifiedExpectation.fulfill()
        }
        wait(for: [notModifiedExpectation], timeout: 2)
        XCTAssertEqual(etag, MockHTTP.requests.last?.value(forHTTPHeaderField: "If-None-Match"))
    }
}
