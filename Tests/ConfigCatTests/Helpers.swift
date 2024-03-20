import Foundation
import XCTest
@testable import ConfigCat

extension String {
    func toEntryFromConfigString() -> ConfigEntry {
        return try! ConfigEntry.fromConfigJson(json: self, eTag: "", fetchTime: .distantPast).get()
    }

    func asEntryString(date: Date = Date()) -> String {
        toEntryFromConfigString().withFetchTime(time: date).serialize()
    }
    
    func removeTrailingNewLine() -> String {
        if self.hasSuffix("\n") {
            return String(self.dropLast())
        }
        return self
    }
    
    static func random(len: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<len).map{ _ in letters.randomElement()! })
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
    Config(preferences: .empty, settings: [
        "key": Setting(value: SettingValue(boolValue: nil,
                                           stringValue: "def",
                                           doubleValue: nil,
                                           intValue: nil),
                       variationId: "defVar",
                       percentageAttribute: "",
                       settingType: .string,
                       percentageOptions: [],
                       targetingRules: [
                        TargetingRule(servedValue: ServedValue(value: SettingValue(boolValue: nil, stringValue: "fake1", doubleValue: nil, intValue: nil), variationId: "id1"),
                                      conditions: [
                                        Condition(userCondition: UserCondition(stringValue: nil,
                                                                               doubleValue: nil,
                                                                               stringArrayValue: ["@test1.com"],
                                                                               comparator: .contains,
                                                                               comparisonAttribute: "Identifier"),
                                                  segmentCondition: nil,
                                                  prerequisiteFlagCondition: nil)
                                      ],
                                      percentageOptions: []),
                        TargetingRule(servedValue: ServedValue(value: SettingValue(boolValue: nil, stringValue: "fake2", doubleValue: nil, intValue: nil), variationId: "id2"),
                                      conditions: [
                                        Condition(userCondition: UserCondition(stringValue: nil,
                                                                               doubleValue: nil,
                                                                               stringArrayValue: ["@test2.com"],
                                                                               comparator: .contains,
                                                                               comparisonAttribute: "Identifier"),
                                                  segmentCondition: nil,
                                                  prerequisiteFlagCondition: nil)
                                      ],
                                      percentageOptions: [])
                        ]
    )])
}

func randomSdkKey() -> String {
    return "\(String.random(len: 22))/\(String.random(len: 22))"
}

func loadResource(bundle: Bundle, path: String) -> String? {
    guard let url = bundle.url(forResource: path, withExtension: nil), let matrixData = try? Data(contentsOf: url), let content = String(bytes: matrixData, encoding: .utf8) else {
        return nil
    }
    return content
}

func parseDate(val: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return dateFormatter.date(from:val)!
}

func parseDateTZ(val: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
    return dateFormatter.date(from:val)!
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

extension Array {
    func skip(count: Int) -> [Element] {
        [Element](self[count..<self.count])
    }
}

class RecordingLogger: ConfigCatLogger {
    var entries: [String] = []
    
    func debug(message: String) {
        entries.append("DEBUG \(message)")
    }
    
    func warning(message: String) {
        entries.append("WARNING \(message)")
    }
    
    func info(message: String) {
        entries.append("INFO \(message)")
    }
    
    func error(message: String) {
        entries.append("ERROR \(message)")
    }
    
    func reset() {
        entries = []
    }
}

class TestDictionaryDataSource: OverrideDataSource {
    private var settings: [String: Setting] = [:]

    public init(source: [String: Any?], behaviour: OverrideBehaviour) {
        super.init(behaviour: behaviour)
        for (key, value) in source {
            settings[key] = Setting.fromAnyValue(value: value)
        }
    }

    public override func getOverrides() -> [String: Setting] {
        settings
    }
}

class BundleResourceDataSource: OverrideDataSource {
    private var settings: [String: Setting] = [:]

    public init(json: String, behaviour: OverrideBehaviour) throws {
        super.init(behaviour: behaviour)
        let result = ConfigEntry.fromConfigJson(json: json, eTag: "", fetchTime: Date())
        switch result {
        case .success(let entry):
            self.settings = entry.config.settings
        case .failure(let err):
            throw err
        }
    }

    public override func getOverrides() -> [String: Setting] {
        settings
    }
}
