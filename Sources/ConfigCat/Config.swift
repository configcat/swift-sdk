import Foundation

enum RedirectMode: Int {
    case noRedirect
    case shouldRedirect
    case forceRedirect
}

@objc public enum SegmentComparator: Int {
    /// Matches when the conditions of the specified segment are evaluated to true.
    case isIn
    /// Matches when the conditions of the specified segment are evaluated to false.
    case isNotIn
    
    var text: String {
        switch self {
        case .isIn:
            return "IS IN SEGMENT"
        default:
            return "IS NOT IN SEGMENT"
        }
    }
}

@objc public enum PrerequisiteComparator: Int {
    /// Matches when the evaluated value of the specified prerequisite flag is equal to the comparison value.
    case eq
    /// Matches when the evaluated value of the specified prerequisite flag is not equal to the comparison value.
    case notEq
    
    var text: String {
        switch self {
        case .eq:
            return "EQUALS"
        default:
            return "NOT EQUALS"
        }
    }
}

@objc public enum SettingType: Int {
    case unknown = -1
    /// The on/off type (feature flag).
    case bool = 0
    /// The text setting type.
    case string = 1
    /// The whole number setting type.
    case int = 2
    /// The decimal number setting type.
    case double = 3
}

@objc public enum Comparator: Int {
    /// Matches when the comparison attribute is equal to any of the comparison values.
    case oneOf
    /// Matches when the comparison attribute is not equal to any of the comparison values.
    case notOneOf
    /// Matches when the comparison attribute contains any comparison values as a substring.
    case contains
    /// Matches when the comparison attribute does not contain any comparison values as a substring.
    case notContains
    /// Matches when the comparison attribute interpreted as a semantic version is equal to any of the comparison values.
    case oneOfSemver
    /// Matches when the comparison attribute interpreted as a semantic version is not equal to any of the comparison values.
    case notOneOfSemver
    /// Matches when the comparison attribute interpreted as a semantic version is less than the comparison value.
    case lessSemver
    /// Matches when the comparison attribute interpreted as a semantic version is less than or equal to the comparison value.
    case lessEqSemver
    /// Matches when the comparison attribute interpreted as a semantic version is greater than the comparison value.
    case greaterSemver
    /// Matches when the comparison attribute interpreted as a semantic version is greater than or equal to the comparison value.
    case greaterEqSemver
    /// Matches when the comparison attribute interpreted as a decimal number is equal to the comparison value.
    case eqNum
    /// Matches when the comparison attribute interpreted as a decimal number is not equal to the comparison value.
    case notEqNum
    /// Matches when the comparison attribute interpreted as a decimal number is less than the comparison value.
    case lessNum
    /// Matches when the comparison attribute interpreted as a decimal number is less than or equal to the comparison value.
    case lessEqNum
    /// Matches matches when the comparison attribute interpreted as a decimal number is greater than the comparison value.
    case greaterNum
    /// Matches when the comparison attribute interpreted as a decimal number is greater than or equal to the comparison value.
    case greaterEqNum
    /// Matches when the comparison attribute is equal to any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case oneOfHashed
    /// Matches when the comparison attribute is not equal to any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notOneOfHashed
    /// Matches matches when the comparison attribute interpreted as the seconds elapsed since Unix Epoch is less than the comparison value.
    case beforeDateTime
    /// Matches when the comparison attribute interpreted as the seconds elapsed since Unix Epoch is greater than the comparison value.
    case afterDateTime
    /// Matches when the comparison attribute is equal to the comparison value (where the comparison is performed using the salted SHA256 hashes of the values).
    case eqHashed
    /// Matches when the comparison attribute is not equal to the comparison value (where the comparison is performed using the salted SHA256 hashes of the values).
    case notEqHashed
    /// Matches when the comparison attribute starts with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case startsWithAnyOfHashed
    /// Matches when the comparison attribute does not start with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notStartsWithAnyOfHashed
    /// Matches when the comparison attribute ends with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case endsWithAnyOfHashed
    /// Matches when the comparison attribute does not end with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notEndsWithAnyOfHashed
    /// Matches when the comparison attribute interpreted as a string list contains any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case arrayContainsAnyOfHashed
    /// Matches when the comparison attribute interpreted as a string list does not contain any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case arrayNotContainsAnyOfHashed
    //// Matches when the comparison attribute is equal to the comparison value.
    case eq
    /// Matches when the comparison attribute is not equal to the comparison value.
    case notEq
    /// Matches when the comparison attribute starts with any of the comparison values.
    case startsWithAnyOf
    /// OpNotStartsWithAnyOf matches when the comparison attribute does not start with any of the comparison values.
    case notStartsWithAnyOf
    /// Matches when the comparison attribute ends with any of the comparison values.
    case endsWithAnyOf
    /// Matches when the comparison attribute does not end with any of the comparison values.
    case notEndsWithAnyOf
    /// Matches when the comparison attribute interpreted as a string list contains any of the comparison values.
    case arrayContainsAnyOf
    /// Matches when the comparison attribute interpreted as a string list does not contain any of the comparison values.
    case arrayNotContainsAnyOf
    
    var isSensitive: Bool {
        switch self {
        case .oneOfHashed, .notOneOfHashed, .eqHashed, .notEqHashed, .startsWithAnyOfHashed, .notStartsWithAnyOfHashed,
            .endsWithAnyOfHashed, .notEndsWithAnyOfHashed, .arrayContainsAnyOfHashed, .arrayNotContainsAnyOfHashed:
            return true
        default:
            return false
        }
    }
    
    var isStartsWith: Bool {
        switch self {
        case .startsWithAnyOf, .startsWithAnyOfHashed, .notStartsWithAnyOf, .notStartsWithAnyOfHashed:
            return true
        default:
            return false
        }
    }
    
    var isDateTime: Bool {
        switch self {
        case .afterDateTime, .beforeDateTime:
            return true
        default:
            return false
        }
    }
}

let comparatorTexts: [Comparator: String] = [
    .oneOf:                       "IS ONE OF",
    .notOneOf:                    "IS NOT ONE OF",
    .contains:                    "CONTAINS ANY OF",
    .notContains:                 "NOT CONTAINS ANY OF",
    .oneOfSemver:                 "IS ONE OF",
    .notOneOfSemver:              "IS NOT ONE OF",
    .lessSemver:                  "<",
    .lessEqSemver:                "<=",
    .greaterSemver:               ">",
    .greaterEqSemver:             ">=",
    .eqNum:                       "=",
    .notEqNum:                    "!=",
    .lessNum:                     "<",
    .lessEqNum:                   "<=",
    .greaterNum:                  ">",
    .greaterEqNum:                ">=",
    .oneOfHashed:                 "IS ONE OF",
    .notOneOfHashed:              "IS NOT ONE OF",
    .beforeDateTime:              "BEFORE",
    .afterDateTime:               "AFTER",
    .eqHashed:                    "EQUALS",
    .notEqHashed:                 "NOT EQUALS",
    .startsWithAnyOfHashed:       "STARTS WITH ANY OF",
    .notStartsWithAnyOfHashed:    "NOT STARTS WITH ANY OF",
    .endsWithAnyOfHashed:         "ENDS WITH ANY OF",
    .notEndsWithAnyOfHashed:      "NOT ENDS WITH ANY OF",
    .arrayContainsAnyOfHashed:    "ARRAY CONTAINS ANY OF",
    .arrayNotContainsAnyOfHashed: "ARRAY NOT CONTAINS ANY OF",
    .eq:                          "EQUALS",
    .notEq:                       "NOT EQUALS",
    .startsWithAnyOf:             "STARTS WITH ANY OF",
    .notStartsWithAnyOf:          "NOT STARTS WITH ANY OF",
    .endsWithAnyOf:               "ENDS WITH ANY OF",
    .notEndsWithAnyOf:            "NOT ENDS WITH ANY OF",
    .arrayContainsAnyOf:          "ARRAY CONTAINS ANY OF",
    .arrayNotContainsAnyOf:       "ARRAY NOT CONTAINS ANY OF",
]

protocol JsonSerializable {
    func toJsonMap() -> [String: Any]
}

class ConfigEntry: Equatable {
    static func ==(lhs: ConfigEntry, rhs: ConfigEntry) -> Bool {
        lhs.eTag == rhs.eTag
    }

    let config: Config
    let configJson: String
    let eTag: String
    let fetchTime: Date

    init(config: Config = Config.empty, configJson: String = "", eTag: String = "", fetchTime: Date = .distantPast) {
        self.config = config
        self.eTag = eTag
        self.fetchTime = fetchTime
        self.configJson = configJson
    }

    func withFetchTime(time: Date) -> ConfigEntry {
        ConfigEntry(config: config, configJson: configJson, eTag: eTag, fetchTime: time)
    }
    
    func isExpired(seconds: Int) -> Bool {
        return Date().subtract(seconds: seconds)! > fetchTime;
    }

    static func fromConfigJson(json: String, eTag: String, fetchTime: Date) -> Result<ConfigEntry, Error>  {
        do {
            guard let data = json.data(using: .utf8) else {
                return .failure(ParseError(message: "Decode to utf8 data failed."))
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return .failure(ParseError(message: "Convert to [String: Any] map failed."))
            }
            
            return .success(ConfigEntry(config: .fromJson(json: jsonObject), configJson: json, eTag: eTag, fetchTime: fetchTime))
        } catch {
            return .failure(error)
        }
    }
    
    static func fromCached(cached: String) -> Result<ConfigEntry, Error> {
        guard let timeIndex = cached.firstIndex(of: "\n") else {
            return .failure(ParseError(message: "Number of values is fewer than expected."))
        }
        let withoutTime = String(cached.suffix(from: cached.index(timeIndex, offsetBy: 1)))
        guard let eTagIndex = withoutTime.firstIndex(of: "\n") else {
            return .failure(ParseError(message: "Number of values is fewer than expected."))
        }
        
        let timeString = String(cached[..<timeIndex])
        guard let time = Double(timeString) else {
            return .failure(ParseError(message: String(format: "Invalid fetch time: %@", timeString)))
        }
        
        let configJson = String(withoutTime.suffix(from: withoutTime.index(eTagIndex, offsetBy: 1)))
        let eTag = String(withoutTime[..<eTagIndex])
        
        return fromConfigJson(json: configJson, eTag: eTag, fetchTime: Date(timeIntervalSince1970: time / 1000))
    }

    func serialize() -> String {
        String(format: "%.0f", floor(fetchTime.timeIntervalSince1970 * 1000)) + "\n" + eTag + "\n" + configJson
    }

    var isEmpty: Bool {
        get {
            self === ConfigEntry.empty
        }
    }

    static let empty = ConfigEntry(eTag: "empty")
}

@objc public protocol ConfigProtocol {
    /// The dictionary of settings.
    @objc var settings: [String: Setting] { get }
    /// The list of segments.
    @objc var segments: [Segment] { get }
    
    @objc var salt: String { get }
}

class Config: ConfigProtocol, JsonSerializable {
    
    static let preferencesKey = "p"
    static let settingsKey = "f"
    static let segmentsKey = "s"

    let preferences: Preferences
    let settings: [String: Setting]
    let segments: [Segment]
    let salt: String

    init(preferences: Preferences, settings: [String: Setting] = [:], segments: [Segment] = []) {
        self.preferences = preferences
        self.settings = settings
        self.segments = segments
        self.salt = preferences.salt
    }

    static func fromJson(json: [String: Any]) -> Config {
        let settingsMap = json[self.settingsKey] as? [String: Any] ?? [:]
        let settings: [String: Setting] = settingsMap.mapValues { setting in
            .fromJson(json: setting as? [String: Any] ?? [:])
        }
        let segmentsMap = json[self.segmentsKey] as? [[String: Any]] ?? []
        let segments: [Segment] = segmentsMap.map { segment in
            .fromJson(json: segment)
        }
        var preferences: Preferences = .empty
        if let pref = json[Config.preferencesKey] as? [String: Any] {
            preferences = .fromJson(json: pref)
        }
        for setting in settings {
            setting.value.salt = preferences.salt
            for rule in setting.value.targetingRules {
                for condition in rule.conditions {
                    if let cond = condition.segmentCondition {
                        cond.segment = segments.count > cond.index ? segments[cond.index] : nil
                    }
                }
            }
        }
        if let preferences = json[Config.preferencesKey] as? [String: Any] {
            return Config(preferences: .fromJson(json: preferences), settings: settings, segments: segments)
        }
        return Config(preferences: .empty, settings: settings, segments: segments)
    }

    func toJsonMap() -> [String: Any] {
        var result: [String: Any] = [
            Config.settingsKey: settings.mapValues { setting in
                setting.toJsonMap()
            },
        ]
        if !preferences.isEmpty {
            result[Config.preferencesKey] = preferences.toJsonMap()
        }
        return result
    }

    var isEmpty: Bool {
        get {
            settings.isEmpty
        }
    }
    static let empty = Config(preferences: .empty)
}

class Preferences: JsonSerializable {
    static let preferencesUrlKey = "u"
    static let preferencesRedirectKey = "r"
    static let saltKey = "s"

    let preferencesUrl: String
    let preferencesRedirect: RedirectMode
    let salt: String

    init(preferencesUrl: String, preferencesRedirect: RedirectMode, salt: String) {
        self.preferencesUrl = preferencesUrl
        self.preferencesRedirect = preferencesRedirect
        self.salt = salt
    }

    static func fromJson(json: [String: Any]) -> Preferences {
        Preferences(preferencesUrl: json[self.preferencesUrlKey] as? String ?? "",
                    preferencesRedirect: RedirectMode(rawValue: (json[self.preferencesRedirectKey] as? Int ?? 0)) ?? .noRedirect,
                    salt: json[self.saltKey] as? String ?? "")
    }
    
    static let empty = Preferences(preferencesUrl: "", preferencesRedirect: .noRedirect, salt: "")

    var isEmpty: Bool {
        get {
            self === Preferences.empty
        }
    }
    
    func toJsonMap() -> [String: Any] {
        [
            Preferences.preferencesUrlKey: preferencesUrl,
            Preferences.preferencesRedirectKey: preferencesRedirect.rawValue,
            Preferences.saltKey: salt,
        ]
    }
}

public final class Setting: NSObject, JsonSerializable {
    static let valueKey = "v"
    static let percentageAttributeKey = "a"
    static let settingTypeKey = "t"
    static let percentageOptionsKey = "p"
    static let targetingRulesKey = "r"
    static let variationIdKey = "i"

    /// The setting's default value used when no targeting rules are matching during an evaluation process.
    @objc public let value: SettingValue

    /// The list of percentage options.
    @objc public let percentageOptions: [PercentageOption]

    /// The list of targeting rules (where there is a logical OR relation between the items).
    @objc public let targetingRules: [TargetingRule]

    /// Variation ID (for analytical purposes).
    @objc public let variationId: String
    
    /// The User Object attribute which serves as the basis of percentage options evaluation.
    @objc public let percentageAttribute: String
    
    /// The setting's type. It can be Bool, String, Int, Float.
    @objc public let settingType: SettingType
    
    var salt: String = ""

    init(value: SettingValue, variationId: String, percentageAttribute: String, settingType: SettingType, percentageOptions: [PercentageOption], targetingRules: [TargetingRule]) {
        self.value = value
        self.percentageAttribute = percentageAttribute
        self.settingType = settingType
        self.variationId = variationId;
        self.percentageOptions = percentageOptions
        self.targetingRules = targetingRules
    }

    static func fromJson(json: [String: Any]) -> Setting {
        let targetingRules = json[self.targetingRulesKey] as? [[String: Any]] ?? []
        let percentageOptions = json[self.percentageOptionsKey] as? [[String: Any]] ?? []

        return Setting(value: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                       variationId: json[self.variationIdKey] as? String ?? "",
                       percentageAttribute: json[self.percentageAttributeKey] as? String ?? "",
                       settingType: SettingType(rawValue: (json[self.settingTypeKey] as? Int ?? -1)) ?? .unknown,
                       percentageOptions: percentageOptions.map { opt in
                           .fromJson(json: opt)
                       },
                       targetingRules: targetingRules.map { rule in
                           .fromJson(json: rule)
                       })
    }

    func toJsonMap() -> [String: Any] {
        [
            Setting.valueKey: value.toJsonMap(),
            Setting.variationIdKey: variationId,
            Setting.percentageAttributeKey: percentageAttribute,
            Setting.settingTypeKey: settingType.rawValue,
            Setting.percentageOptionsKey: percentageOptions.map { opt in
                opt.toJsonMap()
            },
            Setting.targetingRulesKey: targetingRules.map { rule in
                rule.toJsonMap()
            },
        ]
    }
    
    static func fromAnyValue(value: Any?) -> Setting {
        switch value {
        case let val as String:
            return Setting(value: SettingValue(boolValue: nil, stringValue: val, doubleValue: nil, intValue: nil), variationId: "", percentageAttribute: "", settingType: .string, percentageOptions: [], targetingRules: [])
        case let val as Bool:
            return Setting(value: SettingValue(boolValue: val, stringValue: nil, doubleValue: nil, intValue: nil), variationId: "", percentageAttribute: "", settingType: .bool, percentageOptions: [], targetingRules: [])
        case let val as Double:
            return Setting(value: SettingValue(boolValue: nil, stringValue: nil, doubleValue: val, intValue: nil), variationId: "", percentageAttribute: "", settingType: .double, percentageOptions: [], targetingRules: [])
        case let val as Int:
            return Setting(value: SettingValue(boolValue: nil, stringValue: nil, doubleValue: nil, intValue: val), variationId: "", percentageAttribute: "", settingType: .int, percentageOptions: [], targetingRules: [])
        default:
            return Setting(value: SettingValue(invalidValue: value), variationId: "", percentageAttribute: "", settingType: .unknown, percentageOptions: [], targetingRules: [])
        }
    }
}

public final class Segment: NSObject, JsonSerializable {
    static let nameKey = "n"
    static let conditionsKey = "r"

    /// The first 4 characters of the Segment's name.
    @objc public let name: String

    /// The list of segment rule conditions (has a logical AND relation between the items).
    @objc public let conditions: [UserCondition]

    init(name: String, conditions: [UserCondition]) {
        self.name = name
        self.conditions = conditions
    }

    static func fromJson(json: [String: Any]) -> Segment {
        let conditions = json[self.conditionsKey] as? [[String: Any]] ?? []
        
        return Segment(name: json[self.nameKey] as? String ?? "",
                       conditions: conditions.map { cond in
                           .fromJson(json: cond)
                       })
    }

    func toJsonMap() -> [String: Any] {
        [
            Segment.nameKey: name,
            Segment.conditionsKey: conditions.map { cond in
                cond.toJsonMap()
            }
        ]
    }
}

public final class TargetingRule: NSObject, JsonSerializable {
    static let valueKey = "s"
    static let conditionsKey = "c"
    static let percentageOptionsKey = "p"

    /// The value associated with the targeting rule or nil if the targeting rule has percentage options THEN part.
    @objc public let servedValue: ServedValue

    /// The list of conditions that are combined with the AND logical operator.
    @objc public let conditions: [Condition]

    /// The list of percentage options associated with the targeting rule or nil if the targeting rule has a served value THEN part.
    @objc public let percentageOptions: [PercentageOption]

    init(servedValue: ServedValue, conditions: [Condition], percentageOptions: [PercentageOption]) {
        self.servedValue = servedValue
        self.conditions = conditions
        self.percentageOptions = percentageOptions
    }

    static func fromJson(json: [String: Any]) -> TargetingRule {
        let conditions = json[self.conditionsKey] as? [[String: Any]] ?? []
        let percentageOptions = json[self.percentageOptionsKey] as? [[String: Any]] ?? []
        
        return TargetingRule(servedValue: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                             conditions: conditions.map { cond in
                                .fromJson(json: cond)
                             },
                             percentageOptions: percentageOptions.map { opt in
                                .fromJson(json: opt)
                             })
    }

    func toJsonMap() -> [String: Any] {
        [
            TargetingRule.valueKey: servedValue.toJsonMap(),
            TargetingRule.conditionsKey: conditions.map { cond in
                cond.toJsonMap()
            },
            TargetingRule.percentageOptionsKey: percentageOptions.map { opt in
                opt.toJsonMap()
            }
        ]
    }
}

public final class Condition: NSObject, JsonSerializable {
    static let userKey = "u"
    static let segmentKey = "s"
    static let prereqKey = "p"

    /// Describes a condition that works with User Object attributes.
    @objc public let userCondition: UserCondition?

    /// Describes a condition that works with a segment.
    @objc public let segmentCondition: SegmentCondition?
    
    /// Describes a condition that works with a prerequisite flag.
    @objc public let prerequisiteFlagCondition: PrerequisiteFlagCondition?

    init(userCondition: UserCondition?, segmentCondition: SegmentCondition?, prerequisiteFlagCondition: PrerequisiteFlagCondition?) {
        self.userCondition = userCondition
        self.segmentCondition = segmentCondition
        self.prerequisiteFlagCondition = prerequisiteFlagCondition
    }

    static func fromJson(json: [String: Any]) -> Condition {
        if let cond = json[self.userKey] as? [String: Any] {
            return Condition(userCondition: .fromJson(json: cond), segmentCondition: nil, prerequisiteFlagCondition: nil)
        }
        if let cond = json[self.segmentKey] as? [String: Any] {
            return Condition(userCondition: nil, segmentCondition: .fromJson(json: cond), prerequisiteFlagCondition: nil)
        }
        if let cond = json[self.prereqKey] as? [String: Any] {
            return Condition(userCondition: nil, segmentCondition: nil, prerequisiteFlagCondition: .fromJson(json: cond))
        }
        return Condition(userCondition: nil, segmentCondition: nil, prerequisiteFlagCondition: nil)
    }

    func toJsonMap() -> [String: Any] {
        var result: [String: Any] = [:]
        if let cond = userCondition {
            result[Condition.userKey] = cond.toJsonMap()
        }
        if let cond = segmentCondition {
            result[Condition.segmentKey] = cond.toJsonMap()
        }
        if let cond = prerequisiteFlagCondition {
            result[Condition.prereqKey] = cond.toJsonMap()
        }
        return result
    }
}

public final class UserCondition: NSObject, JsonSerializable {
    static let stringListMaxLength = 10
    static let comparatorKey = "c"
    static let comparisonAttributeKey = "a"
    static let stringValKey = "s"
    static let doubleValKey = "d"
    static let stringArrValKey = "l"

    /// Value in text format that the User Object attribute is compared to.
    @objc public let stringValue: String?
    
    /// Value in numeric format that the User Object attribute is compared to.
    public let doubleValue: Double?
    
    /// Value in numeric Objective-C format that the User Object attribute is compared to.
    @objc public let doubleValueObjC: NSNumber?
    
    /// Value in text array format that the User Object attribute is compared to.
    @objc public let stringArrayValue: [String]?

    /// The operator which defines the relation between the comparison attribute and the comparison value.
    @objc public let comparator: Comparator

    /// The User Object attribute that the condition is based on. Can be "Identifier", "Email", "Country" or any custom attribute.
    @objc public let comparisonAttribute: String

    init(stringValue: String?, doubleValue: Double?, stringArrayValue: [String]?, comparator: Comparator, comparisonAttribute: String) {
        self.stringValue = stringValue
        self.doubleValue = doubleValue
        self.stringArrayValue = stringArrayValue
        self.comparator = comparator
        self.comparisonAttribute = comparisonAttribute
        if let val = doubleValue {
            self.doubleValueObjC = NSNumber(value: val)
        } else {
            self.doubleValueObjC = nil
        }
    }

    static func fromJson(json: [String: Any]) -> UserCondition {
        UserCondition(stringValue: json[self.stringValKey] as? String,
                      doubleValue: json[self.doubleValKey] as? Double,
                      stringArrayValue: json[self.stringArrValKey] as? [String],
                      comparator: Comparator(rawValue: (json[self.comparatorKey] as? Int ?? 0)) ?? .oneOf,
                      comparisonAttribute: json[self.comparisonAttributeKey] as? String ?? "")
    }

    func toJsonMap() -> [String: Any] {
        [
            UserCondition.stringValKey: stringValue as Any,
            UserCondition.doubleValKey: doubleValue as Any,
            UserCondition.stringArrValKey: stringArrayValue as Any,
            UserCondition.comparatorKey: comparator.rawValue,
            UserCondition.comparisonAttributeKey: comparisonAttribute,
        ]
    }
    
    public override var description: String {
        let res = "User.\(comparisonAttribute) \(comparatorTexts[comparator]!) "
        if stringValue == nil && doubleValue == nil && stringArrayValue == nil {
            return res + "<invalid value>"
        }
        if let number = doubleValue {
            return res + (comparator.isDateTime ? String(format: "'%.0f' (\(Date(timeIntervalSince1970: number)) UTC)", number) : "'\(String(format: "%g", number))'")
        }
        if let text = stringValue {
            return res + "'\(comparator.isSensitive ? "<hashed value>" : text)'"
        }
        if let arr = stringArrayValue, !arr.isEmpty {
            if comparator.isSensitive {
                let valText = arr.count > 1 ? "values" : "value"
                return res + "[<\(arr.count) hashed \(valText)>]"
            } else {
                let valText = arr.count - UserCondition.stringListMaxLength > 1 ? "values" : "value"
                let limit = arr.count > UserCondition.stringListMaxLength ? UserCondition.stringListMaxLength : arr.count
                var arrText = ""
                for (index, item) in arr.enumerated() {
                    arrText += "'"+item+"'"
                    if index < limit-1 {
                        arrText += ", "
                    } else if arr.count > UserCondition.stringListMaxLength {
                        arrText += ", ... <\(arr.count - UserCondition.stringListMaxLength) more \(valText)>"
                        break
                    }
                }
                return res + "[\(arrText)]"
            }
        }
        return res
    }
}

public final class SegmentCondition: NSObject, JsonSerializable {
    static let indexKey = "s"
    static let comparatorKey = "c"

    /// Identifies the segment that the condition is based on.
    @objc public let index: Int

    /// The operator which defines the expected result of the evaluation of the segment.
    @objc public let segmentComparator: SegmentComparator
    
    var segment: Segment?

    init(index: Int, segmentComparator: SegmentComparator) {
        self.index = index
        self.segmentComparator = segmentComparator
    }

    static func fromJson(json: [String: Any]) -> SegmentCondition {
        SegmentCondition(index: json[self.indexKey] as? Int ?? -1,
                         segmentComparator: SegmentComparator(rawValue: (json[self.comparatorKey] as? Int ?? 0)) ?? .isIn)
    }

    func toJsonMap() -> [String: Any] {
        [
            SegmentCondition.indexKey: index,
            SegmentCondition.comparatorKey: segmentComparator.rawValue,
        ]
    }
    
    public override var description: String {
        return "User \(segmentComparator.text) '\(segment?.name ?? "<invalid name>")'"
    }
}

public final class PrerequisiteFlagCondition: NSObject, JsonSerializable {
    static let flagKeyKey = "f"
    static let comparatorKey = "c"
    static let valueKey = "v"

    /// The key of the prerequisite flag that the condition is based on.
    @objc public let flagKey: String

    /// The operator which defines the relation between the evaluated value of the prerequisite flag and the comparison value.
    @objc public let prerequisiteComparator: PrerequisiteComparator
    
    /// The evaluated value of the prerequisite flag is compared to.
    @objc public let flagValue: SettingValue

    init(flagKey: String, prerequisiteComparator: PrerequisiteComparator, flagValue: SettingValue) {
        self.flagKey = flagKey
        self.prerequisiteComparator = prerequisiteComparator
        self.flagValue = flagValue
    }

    static func fromJson(json: [String: Any]) -> PrerequisiteFlagCondition {
        PrerequisiteFlagCondition(flagKey: json[self.flagKeyKey] as? String ?? "",
                                  prerequisiteComparator: PrerequisiteComparator(rawValue: (json[self.comparatorKey] as? Int ?? 0)) ?? .eq,
                                  flagValue: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]))
    }

    func toJsonMap() -> [String: Any] {
        [
            PrerequisiteFlagCondition.flagKeyKey: flagKey,
            PrerequisiteFlagCondition.comparatorKey: prerequisiteComparator.rawValue,
            PrerequisiteFlagCondition.valueKey: flagValue.toJsonMap()
        ]
    }
    
    public override var description: String {
        return "Flag '\(flagKey)' \(prerequisiteComparator.text) '\(flagValue.val ?? "<invalid value>")'"
    }
}

public final class SettingValue: NSObject, JsonSerializable {
    static let boolKey = "b"
    static let stringKey = "s"
    static let doubleKey = "d"
    static let intKey = "i"

    /// Holds a bool feature flag's value.
    public let boolValue: Bool?
    
    @objc public let boolValueObjC: NSNumber?
    
    /// Holds a string setting's value.
    @objc public let stringValue: String?
    
    /// Holds a decimal number setting's value.
    public let doubleValue: Double?
    
    @objc public let doubleValueObjC: NSNumber?
    
    /// Holds a whole number setting's value.
    public let intValue: Int?
    
    @objc public let intValueObjC: NSNumber?
    
    let invalidValue: Any?

    init(boolValue: Bool?, stringValue: String?, doubleValue: Double?, intValue: Int?, invalidValue: Any? = nil) {
        self.boolValue = boolValue
        self.stringValue = stringValue
        self.doubleValue = doubleValue
        self.intValue = intValue
        self.invalidValue = invalidValue
        
        if let val = boolValue {
            self.boolValueObjC = NSNumber(value: val)
        } else {
            self.boolValueObjC = nil
        }
        if let val = doubleValue {
            self.doubleValueObjC = NSNumber(value: val)
        } else {
            self.doubleValueObjC = nil
        }
        if let val = intValue {
            self.intValueObjC = NSNumber(value: val)
        } else {
            self.intValueObjC = nil
        }
    }
    
    convenience init(invalidValue: Any?) {
        self.init(boolValue: nil, stringValue: nil, doubleValue: nil, intValue: nil, invalidValue: invalidValue)
    }

    static func fromJson(json: [String: Any]) -> SettingValue {
        SettingValue(boolValue: json[self.boolKey] as? Bool,
                     stringValue: json[self.stringKey] as? String,
                     doubleValue: json[self.doubleKey] as? Double,
                     intValue: json[self.intKey] as? Int)
    }

    func toJsonMap() -> [String: Any] {
        [
            SettingValue.boolKey: boolValue as Any,
            SettingValue.stringKey: stringValue as Any,
            SettingValue.doubleKey: doubleValue as Any,
            SettingValue.intKey: intValue as Any,
        ]
    }
    
    static func fromAnyValue(value: Any?) -> SettingValue {
        switch value {
        case let val as String:
            return SettingValue(boolValue: nil, stringValue: val, doubleValue: nil, intValue: nil)
        case let val as Bool:
            return SettingValue(boolValue: val, stringValue: nil, doubleValue: nil, intValue: nil)
        case let val as Double:
            return SettingValue(boolValue: nil, stringValue: nil, doubleValue: val, intValue: nil)
        case let val as Int:
            return SettingValue(boolValue: nil, stringValue: nil, doubleValue: nil, intValue: val)
        default:
            return SettingValue(invalidValue: value)
        }
    }
    
    var settingType: SettingType {
        if boolValue != nil {
            return .bool
        }
        if stringValue != nil {
            return .string
        }
        if doubleValue != nil  {
            return .double
        }
        if intValue != nil {
            return .int
        }
        return .unknown
    }
    
    var val: Any? {
        if let val = boolValue {
            return val
        }
        if let val = stringValue {
            return val
        }
        if let val = doubleValue {
            return val
        }
        if let val = intValue {
            return val
        }
        return nil
    }
    
    var isValid: Bool {
        return boolValue != nil || stringValue != nil || doubleValue != nil || intValue != nil
    }
    
    var isEmpty: Bool {
        return !isValid && invalidValue == nil
    }
    
    func eq(to: Any) -> Bool {
        switch to {
        case let val as String:
            return val == stringValue
        case let val as Bool:
            return val == boolValue
        case let val as Double:
            return val == doubleValue
        case let val as Int:
            return val == intValue
        default:
            return false
        }
    }
}

public final class ServedValue: NSObject, JsonSerializable {
    static let valueKey = "v"
    static let idKey = "i"

    /// The value associated with the targeting rule or nil if the targeting rule has percentage options THEN part.
    @objc public let value: SettingValue
    
    /// VariationID of the targeting rule.
    @objc public let variationId: String?

    init(value: SettingValue, variationId: String?) {
        self.value = value
        self.variationId = variationId
    }

    static func fromJson(json: [String: Any]) -> ServedValue {
        ServedValue(value: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                    variationId: json[self.idKey] as? String)
    }

    func toJsonMap() -> [String: Any] {
        [
            ServedValue.valueKey: value.toJsonMap(),
            ServedValue.idKey: variationId as Any,
        ]
    }
}


public final class PercentageOption: NSObject, JsonSerializable {
    static let valueKey = "v"
    static let percentageKey = "p"
    static let variationIdKey = "i"

    /// The served value of the percentage option.
    @objc public let servedValue: SettingValue

    /// The rule's percentage value.
    @objc public let percentage: Int

    /// The rule's variation ID (for analytical purposes).
    @objc public let variationId: String

    init(servedValue: SettingValue, percentage: Int, variationId: String) {
        self.servedValue = servedValue
        self.percentage = percentage
        self.variationId = variationId;
    }

    static func fromJson(json: [String: Any]) -> PercentageOption {
        PercentageOption(servedValue: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                percentage: json[self.percentageKey] as? Int ?? 0,
                variationId: json[self.variationIdKey] as? String ?? "")
    }

    func toJsonMap() -> [String: Any] {
        [
            PercentageOption.valueKey: servedValue.toJsonMap(),
            PercentageOption.percentageKey: percentage,
            PercentageOption.variationIdKey: variationId
        ]
    }
}
