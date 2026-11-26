import XCTest
@testable import ConfigCat

class ConfigCatClientIntegrationTests: XCTestCase {
    func testGetAllKeys() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.sessionConfiguration.timeoutIntervalForRequest = 10
        }
        defer { client.close() }
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
            options.sessionConfiguration.timeoutIntervalForRequest = 10
        }
        defer { client.close() }
        let expectation = expectation(description: "wait for all values")
        client.getAllValues { allValues in
            XCTAssertEqual(16, allValues.count)
            XCTAssertEqual(.string("Cat"), allValues["stringDefaultCat"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testGetAllValueDetails() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.sessionConfiguration.timeoutIntervalForRequest = 10
        }
        defer { client.close() }
        let expectation = expectation(description: "wait for all values")
        client.getAllValueDetailsObjC { details in
            XCTAssertEqual(16, details.count)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testEvalDetails() {
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.sessionConfiguration.timeoutIntervalForRequest = 10
        }
        defer { client.close() }
        let expectation = expectation(description: "wait for all values")
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")
        client.getValueDetails(for: "stringContainsDogDefaultCat", defaultValue: "", user: user) { details in
            XCTAssertEqual("stringContainsDogDefaultCat", details.key)
            XCTAssertEqual("Dog", details.value)
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertNil(details.error)
            XCTAssertEqual("d0cd8f06", details.variationId)
            XCTAssertEqual("Email", details.matchedTargetingRule?.conditions[0].userCondition?.comparisonAttribute)
            XCTAssertEqual("@configcat.com", details.matchedTargetingRule?.conditions[0].userCondition?.stringArrayValue?.first)
            XCTAssertNil(details.matchedPercentageOption)
            XCTAssertEqual(2, details.matchedTargetingRule?.conditions[0].userCondition?.comparator.rawValue)
            XCTAssertEqual(user.identifier, details.user?.identifier)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }

    func testEvalHook() {
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")
        let flagEvaluated = expectation(description: "flag evaluated hook called")
        let config = ConfigCatOptions.default
        config.pollingMode = PollingModes.lazyLoad()
        config.sessionConfiguration.timeoutIntervalForRequest = 10
        config.hooks.addOnFlagEvaluated { details in
            XCTAssertEqual("stringContainsDogDefaultCat", details.key)
            XCTAssertEqual("Dog", details.value as? String)
            XCTAssertFalse(details.isDefaultValue)
            XCTAssertNil(details.error)
            XCTAssertEqual("d0cd8f06", details.variationId)
            XCTAssertEqual("Email", details.matchedTargetingRule?.conditions[0].userCondition?.comparisonAttribute)
            XCTAssertEqual("@configcat.com", details.matchedTargetingRule?.conditions[0].userCondition?.stringArrayValue?.first)
            XCTAssertNil(details.matchedPercentageOption)
            XCTAssertEqual(2, details.matchedTargetingRule?.conditions[0].userCondition?.comparator.rawValue)
            XCTAssertEqual(user.attribute(for: ConfigCatUser.idKey) as! String, details.user?.attribute(for: ConfigCatUser.idKey) as! String)
            flagEvaluated.fulfill()
        }
        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A", options: config)
        defer { client.close() }
        let expectation = expectation(description: "wait for all values")
        client.getValue(for: "stringContainsDogDefaultCat", defaultValue: "", user: user) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation, flagEvaluated], timeout: 20)
    }

    func testOptionsCallback() {
        let user = ConfigCatUser(identifier: "test@configcat.com", email: "test@configcat.com")

        let client = ConfigCatClient.get(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.defaultUser = user
            options.sessionConfiguration.timeoutIntervalForRequest = 10
        }
        defer { client.close() }
        let expectation = expectation(description: "wait for all values")
        client.getValue(for: "stringContainsDogDefaultCat", defaultValue: "") { value in
            XCTAssertEqual("Dog", value)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 20)
    }
}
