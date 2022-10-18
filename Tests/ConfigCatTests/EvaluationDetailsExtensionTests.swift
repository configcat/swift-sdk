import XCTest
@testable import ConfigCat

class EvaluationDetailsExtensionTests: XCTestCase {
    let testBoolJson = #"{ "f": { "key": { "v": true, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testIntJson = #"{ "f": { "key": { "v": 42, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testDoubleJson = #"{ "f": { "key": { "v": 3.14, "i": "fakeId1", "p": [], "r": [] } } }"#
    let testStringJson = #"{ "f": { "key": { "v": "fake", "i": "fakeId1", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testBoolDetails() {
        MockHTTP.enqueueResponse(response: Response(body: testBoolJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()

        let expectation = expectation(description: "wait for result")
        let details = client.getBoolValueDetails(for: "key", defaultValue: true, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertTrue(details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testIntDetails() {
        MockHTTP.enqueueResponse(response: Response(body: testIntJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()

        let expectation = expectation(description: "wait for result")
        client.getIntValueDetails(for: "key", defaultValue: 0, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual(42, details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testDoubleDetails() {
        MockHTTP.enqueueResponse(response: Response(body: testDoubleJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()

        let expectation = expectation(description: "wait for result")
        client.getDoubleValueDetails(for: "key", defaultValue: 0, user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual(3.14, details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testStringDetails() {
        MockHTTP.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()

        let expectation = expectation(description: "wait for result")
        client.getStringValueDetails(for: "key", defaultValue: "", user: nil) { details in
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertEqual("fake", details.value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testBoolDetailsSync() {
        MockHTTP.enqueueResponse(response: Response(body: testBoolJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()
        let details = client.getBoolValueDetailsSync(for: "key", defaultValue: true, user: nil)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertTrue(details.value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testIntDetailsSync() {
        MockHTTP.enqueueResponse(response: Response(body: testIntJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()
        let details = client.getIntValueDetailsSync(for: "key", defaultValue: 0, user: nil)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertEqual(42, details.value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testDoubleDetailsSync() {
        MockHTTP.enqueueResponse(response: Response(body: testDoubleJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()
        let details = client.getDoubleValueDetailsSync(for: "key", defaultValue: 0, user: nil)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertEqual(3.14, details.value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testStringDetailsSync() {
        MockHTTP.enqueueResponse(response: Response(body: testStringJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), session: MockHTTP.session())
        client.forceRefreshSync()
        let details = client.getStringValueDetailsSync(for: "key", defaultValue: "", user: nil)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertEqual("fake", details.value)
        XCTAssertEqual(1, MockHTTP.requests.count)
    }
}

