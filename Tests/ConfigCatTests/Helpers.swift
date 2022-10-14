import Foundation
import XCTest
@testable import ConfigCat

extension String {
    func toEntryFromConfigString() -> ConfigEntry {
        let data = data(using: .utf8)!
        let jsonObject = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        let config = Config.fromJson(json: jsonObject)
        return ConfigEntry(config: config)
    }

    func asEntryStringWithCurrentDate() -> String {
        toEntryFromConfigString().withFetchTime(time: Date()).toJsonString()
    }
}

extension JsonSerializable {
    func toJsonString() -> String {
        let jsonMap = toJsonMap()
        let json = try! JSONSerialization.data(withJSONObject: jsonMap, options: [])
        return String(data: json, encoding: .utf8)!
    }
}

func createTestConfigWithRules() -> Config {
    Config(entries: ["key": Setting(value: "def", variationId: "defVar", percentageItems: [], rolloutRules: [
        RolloutRule(value: "fake1", variationId: "id1", comparator: 2, comparisonAttribute: "Identifier", comparisonValue: "@test1.com"),
        RolloutRule(value: "fake2", variationId: "id2", comparator: 2, comparisonAttribute: "Identifier", comparisonValue: "@test2.com")
    ])])
}

extension XCTestCase {
    func waitFor(timeout: TimeInterval = 2, predicate: () -> Bool) {
        var end = Date()
        end.addTimeInterval(timeout)
        while (!predicate()) {
            Thread.sleep(forTimeInterval: 0.2)
            if Date() > end {
                XCTFail("Test await timed out.")
                return
            }
        }
    }
}