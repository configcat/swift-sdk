import XCTest
@testable import ConfigCat

class ConfigCatClientIntegrationTests: XCTestCase {
    func testGetAllKeys() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
        }
        let expectation = expectation(description: "wait for all keys")
        client.getAllKeys { keys in
            XCTAssertEqual(16, keys.count)
            XCTAssertTrue(keys.contains("stringDefaultCat"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testGetAllValues() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
        }
        let expectation = expectation(description: "wait for all values")
        client.getAllValues { allValues in
            XCTAssertEqual(16, allValues.count)
            XCTAssertEqual("Cat", allValues["stringDefaultCat"] as! String)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testGetAllValueDetails() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
        }
        let expectation = expectation(description: "wait for all values")
        client.getAllValueDetails { details in
            XCTAssertEqual(16, details.count)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testEvalDetails() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
        }
        let expectation = expectation(description: "wait for all values")
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")
        client.getValueDetails(for: "stringContainsDogDefaultCat", defaultValue: "", user: user) { details in
            XCTAssertEqual("stringContainsDogDefaultCat", details.key)
            XCTAssertEqual("Dog", details.value)
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertNil(details.error)
            XCTAssertEqual("d0cd8f06", details.variationId)
            XCTAssertEqual("Email", details.matchedEvaluationRule?.comparisonAttribute)
            XCTAssertEqual("@configcat.com", details.matchedEvaluationRule?.comparisonValue)
            XCTAssertNil(details.matchedEvaluationPercentageRule)
            XCTAssertEqual(2, details.matchedEvaluationRule?.comparator)
            XCTAssertEqual(user.identifier, details.user?.identifier)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testEvalHook() {
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")
        var called = false
        let config = ConfigCatOptions.default
        config.pollingMode = PollingModes.lazyLoad()
        config.hooks.addOnFlagEvaluated { details in
            XCTAssertEqual("stringContainsDogDefaultCat", details.key)
            XCTAssertEqual("Dog", details.value as? String)
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertNil(details.error)
            XCTAssertEqual("d0cd8f06", details.variationId)
            XCTAssertEqual("Email", details.matchedEvaluationRule?.comparisonAttribute)
            XCTAssertEqual("@configcat.com", details.matchedEvaluationRule?.comparisonValue)
            XCTAssertNil(details.matchedEvaluationPercentageRule)
            XCTAssertEqual(2, details.matchedEvaluationRule?.comparator)
            XCTAssertEqual(user.identifier, details.user?.identifier)
            called = true
        }
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A", options: config)
        let expectation = expectation(description: "wait for all values")
        client.getValue(for: "stringContainsDogDefaultCat", defaultValue: "", user: user) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)

        XCTAssertTrue(called)
    }

    func testOptionsCallback() {
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")

        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.defaultUser = user
        }
        let expectation = expectation(description: "wait for all values")
        client.getValue(for: "stringContainsDogDefaultCat", defaultValue: "") { value in
            XCTAssertEqual("Dog", value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }
}
