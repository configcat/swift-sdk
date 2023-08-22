import XCTest
@testable import ConfigCat

class EvaluationDetailsExtensionTests: XCTestCase {
    let testBoolJson = #"{ "f": { "key": { "v": true, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testIntJson = #"{ "f": { "key": { "v": 42, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testDoubleJson = #"{ "f": { "key": { "v": 3.14, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testStringJson = #"{ "f": { "key": { "v": "fake", "i": "fakeId1", "p": [], "r": [] } } }"#

    func testBoolDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testBoolJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        let refreshExpectation = expectation(description: "wait for refresh")
        client.forceRefresh { RefreshResult in
            refreshExpectation.fulfill()
        }
        wait(for: [refreshExpectation], timeout: 5)

        let expectation = expectation(description: "wait for result")
        client.getBoolValueDetails(for: "key", defaultValue: true, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertTrue(details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, engine.requests.count)
    }

    func testIntDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testIntJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        let refreshExpectation = expectation(description: "wait for refresh")
        client.forceRefresh { RefreshResult in
            refreshExpectation.fulfill()
        }
        wait(for: [refreshExpectation], timeout: 5)

        let expectation = expectation(description: "wait for result")
        client.getIntValueDetails(for: "key", defaultValue: 0, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual(42, details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, engine.requests.count)
    }

    func testDoubleDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testDoubleJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        let refreshExpectation = expectation(description: "wait for refresh")
        client.forceRefresh { RefreshResult in
            refreshExpectation.fulfill()
        }
        wait(for: [refreshExpectation], timeout: 5)

        let expectation = expectation(description: "wait for result")
        client.getDoubleValueDetails(for: "key", defaultValue: 0, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual(3.14, details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, engine.requests.count)
    }

    func testStringDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: engine)
        let refreshExpectation = expectation(description: "wait for refresh")
        client.forceRefresh { RefreshResult in
            refreshExpectation.fulfill()
        }
        wait(for: [refreshExpectation], timeout: 5)

        let expectation = expectation(description: "wait for result")
        client.getStringValueDetails(for: "key", defaultValue: "", user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual("fake", details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, engine.requests.count)
    }
}

