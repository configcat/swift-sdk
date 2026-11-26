import XCTest
@testable import ConfigCat

class EvaluationDetailsExtensionTests: XCTestCase {
    let testBoolJson = #"{ "f": { "key": { "v": { "b": true }, "i": "fakeId1", "t":0 } } }"#
    let testIntJson = #"{ "f": { "key": { "v": { "i": 42 }, "i": "fakeId1", "t":2 } } }"#
    let testDoubleJson = #"{ "f": { "key": { "v": { "d": 3.14 }, "i": "fakeId1", "t":3 } } }"#
    let testStringJson = #"{ "f": { "key": { "v": { "s": "fake" }, "i": "fakeId1", "t":1 } } }"#

    func testEvaluationDetailsShareMetadata() {
        let user = ConfigCatUser(identifier: "user")
        let rule = TargetingRule(servedValue: nil, conditions: [], percentageOptions: [])
        let option = PercentageOption(servedValue: SettingValue(value: .bool(true)), percentage: 100, variationId: "option")
        let date = Date(timeIntervalSince1970: 42)
        let details = EvaluationDetails(
            key: "key", value: true, variationId: "variation", fetchTime: date,
            user: user, isDefaultValue: true, errorCode: .unexpectedError,
            error: "error", matchedTargetingRule: rule, matchedPercentageOption: option
        )
        let boolDetails = TypedEvaluationDetails(value: true, details: details)
        let values: [any HasEvaluationMetadata] = [
            details, boolDetails, boolDetails.toBoolDetails(),
            TypedEvaluationDetails(value: "value", details: details).toStringDetails(),
            TypedEvaluationDetails(value: 1, details: details).toIntDetails(),
            TypedEvaluationDetails(value: 1.5, details: details).toDoubleDetails()
        ]
        for value in values {
            XCTAssertTrue(value.metadata === details.metadata)
            XCTAssertEqual(value.key, "key")
            XCTAssertEqual(value.variationId, "variation")
            XCTAssertTrue(value.user === user)
            XCTAssertTrue(value.isDefaultValue)
            XCTAssertEqual(value.error, "error")
            XCTAssertEqual(value.errorCode, .unexpectedError)
            XCTAssertEqual(value.fetchTime, date)
            XCTAssertTrue(value.matchedTargetingRule === rule)
            XCTAssertTrue(value.matchedPercentageOption === option)
        }
    }

    func testBoolDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testBoolJson, statusCode: 200))

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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

        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
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

