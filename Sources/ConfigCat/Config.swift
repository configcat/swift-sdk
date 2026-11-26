import Foundation

enum RedirectMode: Int, Sendable {
    case unknown = -1
    case noRedirect = 0
    case shouldRedirect = 1
    case forceRedirect = 2
}

@objc public enum SegmentComparator: Int, Sendable {
    case unknown = -1
    /// Checks whether the conditions of the specified segment are evaluated to true.
    case isIn = 0
    /// Checks whether the conditions of the specified segment are evaluated to false.
    case isNotIn = 1
    
    var text: String {
        return self == .isIn ? "IS IN SEGMENT" : "IS NOT IN SEGMENT"
    }
}

@objc public enum PrerequisiteFlagComparator: Int, Sendable {
    case unknown = -1
    /// Checks whether the evaluated value of the specified prerequisite flag is equal to the comparison value.
    case eq = 0
    /// Checks whether the evaluated value of the specified prerequisite flag is not equal to the comparison value.
    case notEq = 1
    
    var text: String {
        return self == .eq ? "EQUALS" : "NOT EQUALS"
    }
}

@objc public enum SettingType: Int, Sendable {
    case unknown = -1
    /// The on/off type (feature flag).
    case bool = 0
    /// The text setting type.
    case string = 1
    /// The whole number setting type.
    case int = 2
    /// The decimal number setting type.
    case double = 3
    
    var text: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .bool:
            return "Bool"
        case .string:
            return "String"
        case .int:
            return "Int"
        case .double:
            return "Double"
        }
    }
}

@objc public enum UserComparator: Int, Sendable {
    case unknown = -1
    /// Checks whether the comparison attribute is equal to any of the comparison values.
    case oneOf = 0
    /// Checks whether the comparison attribute is not equal to any of the comparison values.
    case notOneOf = 1
    /// Checks whether the comparison attribute contains any comparison values as a substring.
    case contains = 2
    /// Checks whether the comparison attribute does not contain any comparison values as a substring.
    case notContains = 3
    /// Checks whether the comparison attribute interpreted as a semantic version is equal to any of the comparison values.
    case oneOfSemver = 4
    /// Checks whether the comparison attribute interpreted as a semantic version is not equal to any of the comparison values.
    case notOneOfSemver = 5
    /// Checks whether the comparison attribute interpreted as a semantic version is less than the comparison value.
    case lessSemver = 6
    /// Checks whether the comparison attribute interpreted as a semantic version is less than or equal to the comparison value.
    case lessEqSemver = 7
    /// Checks whether the comparison attribute interpreted as a semantic version is greater than the comparison value.
    case greaterSemver = 8
    /// Checks whether the comparison attribute interpreted as a semantic version is greater than or equal to the comparison value.
    case greaterEqSemver = 9
    /// Checks whether the comparison attribute interpreted as a decimal number is equal to the comparison value.
    case eqNum = 10
    /// Checks whether the comparison attribute interpreted as a decimal number is not equal to the comparison value.
    case notEqNum = 11
    /// Checks whether the comparison attribute interpreted as a decimal number is less than the comparison value.
    case lessNum = 12
    /// Checks whether the comparison attribute interpreted as a decimal number is less than or equal to the comparison value.
    case lessEqNum = 13
    /// Checks whether the comparison attribute interpreted as a decimal number is greater than the comparison value.
    case greaterNum = 14
    /// Checks whether the comparison attribute interpreted as a decimal number is greater than or equal to the comparison value.
    case greaterEqNum = 15
    /// Checks whether the comparison attribute is equal to any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case oneOfHashed = 16
    /// Checks whether the comparison attribute is not equal to any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notOneOfHashed = 17
    /// Checks whether the comparison attribute interpreted as the seconds elapsed since Unix Epoch is less than the comparison value.
    case beforeDateTime = 18
    /// Checks whether the comparison attribute interpreted as the seconds elapsed since Unix Epoch is greater than the comparison value.
    case afterDateTime = 19
    /// Checks whether the comparison attribute is equal to the comparison value (where the comparison is performed using the salted SHA256 hashes of the values).
    case eqHashed = 20
    /// Checks whether the comparison attribute is not equal to the comparison value (where the comparison is performed using the salted SHA256 hashes of the values).
    case notEqHashed = 21
    /// Checks whether the comparison attribute starts with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case startsWithAnyOfHashed = 22
    /// Checks whether the comparison attribute does not start with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notStartsWithAnyOfHashed = 23
    /// Checks whether the comparison attribute ends with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case endsWithAnyOfHashed = 24
    /// Checks whether the comparison attribute does not end with any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case notEndsWithAnyOfHashed = 25
    /// Checks whether the comparison attribute interpreted as a string list contains any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case arrayContainsAnyOfHashed = 26
    /// Checks whether the comparison attribute interpreted as a string list does not contain any of the comparison values (where the comparison is performed using the salted SHA256 hashes of the values).
    case arrayNotContainsAnyOfHashed = 27
    //// Checks whether the comparison attribute is equal to the comparison value.
    case eq = 28
    /// Checks whether the comparison attribute is not equal to the comparison value.
    case notEq = 29
    /// Checks whether the comparison attribute starts with any of the comparison values.
    case startsWithAnyOf = 30
    /// Checks whether the comparison attribute does not start with any of the comparison values.
    case notStartsWithAnyOf = 31
    /// Checks whether the comparison attribute ends with any of the comparison values.
    case endsWithAnyOf = 32
    /// Checks whether the comparison attribute does not end with any of the comparison values.
    case notEndsWithAnyOf = 33
    /// Checks whether the comparison attribute interpreted as a string list contains any of the comparison values.
    case arrayContainsAnyOf = 34
    /// Checks whether the comparison attribute interpreted as a string list does not contain any of the comparison values.
    case arrayNotContainsAnyOf = 35
    
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

let comparatorTexts: [UserComparator: String] = [
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
    let cacheString: String
    let eTag: String
    let fetchTime: Date
    let isEmpty: Bool

    init(config: Config = Config.empty, configJson: String = "", eTag: String = "", fetchTime: Date = .distantPast, isEmpty: Bool = false) {
        self.config = config
        self.eTag = eTag
        self.fetchTime = fetchTime
        self.configJson = configJson
        self.cacheString = ConfigEntry.toCacheString(configJson: configJson, eTag: eTag, fetchTime: fetchTime)
        self.isEmpty = isEmpty
    }

    func withFetchTime(time: Date) -> ConfigEntry {
        ConfigEntry(config: config, configJson: configJson, eTag: eTag, fetchTime: time)
    }
    
    func isExpired(seconds: Int) -> Bool {
        return Date().addingTimeInterval(-TimeInterval(seconds)) > fetchTime
    }

    static func fromConfigJson(json: String, eTag: String, fetchTime: Date) -> Result<ConfigEntry, Error>  {
        guard let jsonObject: [String: Any] = Utils.fromJson(json: json) else {
            return .failure(ParseError(message: "Config JSON parsing failed."))
        }
        return .success(ConfigEntry(config: .fromJson(json: jsonObject), configJson: json, eTag: eTag, fetchTime: fetchTime))
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

    private static func toCacheString(configJson: String, eTag: String, fetchTime: Date) -> String {
        String(format: "%.0f", floor(fetchTime.timeIntervalSince1970 * 1000)) + "\n" + eTag + "\n" + configJson
    }

    static var empty: ConfigEntry { ConfigEntry(eTag: "empty", isEmpty: true) }
}

public class Config: NSObject, JsonSerializable {
    static let preferencesKey = "p"
    static let settingsKey = "f"
    static let segmentsKey = "s"

    /// The dictionary of settings.
    @objc public let settings: [String: Setting]
    /// The list of segments.
    @objc public let segments: [Segment]
    /// The salt that was used to hash sensitive comparison values.
    @objc public let salt: String?
    
    let preferences: Preferences

    init(preferences: Preferences, settings: [String: Setting] = [:], segments: [Segment] = []) {
        self.preferences = preferences
        self.settings = settings
        self.segments = segments
        self.salt = preferences.salt
    }

    public static func fromJson(json: [String: Any]) -> Config {
        let segmentsMap = json[self.segmentsKey] as? [[String: Any]] ?? []
        let segments: [Segment] = segmentsMap.map { segment in
            .fromJson(json: segment)
        }
        let preferences: Preferences
        if let pref = json[Config.preferencesKey] as? [String: Any] {
            preferences = .fromJson(json: pref)
        } else {
            preferences = .empty
        }
        let settingsMap = json[self.settingsKey] as? [String: Any] ?? [:]
        let settings: [String: Setting] = settingsMap.mapValues { setting in
            .fromJson(json: setting as? [String: Any] ?? [:], segments: segments, salt: preferences.salt)
        }
        return Config(preferences: preferences, settings: settings, segments: segments)
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
    static var empty: Config { Config(preferences: .empty) }
}

final class Preferences: JsonSerializable, Sendable {
    static let preferencesUrlKey = "u"
    static let preferencesRedirectKey = "r"
    static let saltKey = "s"

    let preferencesUrl: String
    let preferencesRedirect: RedirectMode
    let salt: String?

    init(preferencesUrl: String, preferencesRedirect: RedirectMode, salt: String?) {
        self.preferencesUrl = preferencesUrl
        self.preferencesRedirect = preferencesRedirect
        self.salt = salt
    }

    static func fromJson(json: [String: Any]) -> Preferences {
        Preferences(preferencesUrl: json[self.preferencesUrlKey] as? String ?? "",
                    preferencesRedirect: RedirectMode(rawValue: (json[self.preferencesRedirectKey] as? Int ?? -1)) ?? .noRedirect,
                    salt: json[self.saltKey] as? String)
    }
    
    static let empty = Preferences(preferencesUrl: "", preferencesRedirect: .noRedirect, salt: nil)

    var isEmpty: Bool {
        get {
            self === Preferences.empty
        }
    }
    
    func toJsonMap() -> [String: Any] {
        [
            Preferences.preferencesUrlKey: preferencesUrl,
            Preferences.preferencesRedirectKey: preferencesRedirect.rawValue,
            Preferences.saltKey: salt as Any,
        ]
    }
}

public final class Setting: NSObject, JsonSerializable, Sendable {
    static let valueKey = "v"
    static let percentageAttributeKey = "a"
    static let settingTypeKey = "t"
    static let percentageOptionsKey = "p"
    static let targetingRulesKey = "r"
    static let variationIdKey = "i"

    /// The value that is returned when none of the targeting rules or percentage options yield a result.
    @objc public let value: SettingValue

    /// The list of percentage options.
    @objc public let percentageOptions: [PercentageOption]

    /// The list of targeting rules (where there is a logical OR relation between the items).
    @objc public let targetingRules: [TargetingRule]

    /// Variation ID (for analytical purposes).
    @objc public let variationId: String?
    
    /// The User Object attribute which serves as the basis of percentage options evaluation.
    @objc public let percentageAttribute: String
    
    /// The setting's type. It can be `bool`, `string`, `int` or `double`.
    @objc public let settingType: SettingType
    
    let salt: String?

    init(value: SettingValue, variationId: String?, percentageAttribute: String, settingType: SettingType, percentageOptions: [PercentageOption], targetingRules: [TargetingRule], salt: String? = nil) {
        self.value = value
        self.percentageAttribute = percentageAttribute
        self.settingType = settingType
        self.variationId = variationId;
        self.percentageOptions = percentageOptions
        self.targetingRules = targetingRules
        self.salt = salt
    }

    static func fromJson(json: [String: Any], segments: [Segment], salt: String?) -> Setting {
        let targetingRules = json[self.targetingRulesKey] as? [[String: Any]] ?? []
        let percentageOptions = json[self.percentageOptionsKey] as? [[String: Any]] ?? []

        return Setting(value: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                       variationId: json[self.variationIdKey] as? String,
                       percentageAttribute: json[self.percentageAttributeKey] as? String ?? ConfigCatUser.idKey,
                       settingType: SettingType(rawValue: (json[self.settingTypeKey] as? Int ?? -1)) ?? .unknown,
                       percentageOptions: percentageOptions.map { opt in
                           .fromJson(json: opt)
                       },
                       targetingRules: targetingRules.map { rule in
                           .fromJson(json: rule, segments: segments)
                       },
                       salt: salt)
    }

    func toJsonMap() -> [String: Any] {
        [
            Setting.valueKey: value.toJsonMap(),
            Setting.variationIdKey: variationId as Any,
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
    
    public static func fromAnyValue(value: Any?) -> Setting {
        switch value {
        case let val as String:
            return Setting(value: SettingValue(value: .string(val)), variationId: nil, percentageAttribute: "", settingType: .string, percentageOptions: [], targetingRules: [])
        case let val as Bool:
            return Setting(value: SettingValue(value: .bool(val)), variationId: nil, percentageAttribute: "", settingType: .bool, percentageOptions: [], targetingRules: [])
        case let val as Double:
            return Setting(value: SettingValue(value: .double(val)), variationId: nil, percentageAttribute: "", settingType: .double, percentageOptions: [], targetingRules: [])
        case let val as Int:
            return Setting(value: SettingValue(value: .int(val)), variationId: nil, percentageAttribute: "", settingType: .int, percentageOptions: [], targetingRules: [])
        default:
            return Setting(value: SettingValue(invalidValue: value), variationId: "", percentageAttribute: "", settingType: .unknown, percentageOptions: [], targetingRules: [])
        }
    }
}

public final class Segment: NSObject, JsonSerializable, Sendable {
    static let nameKey = "n"
    static let conditionsKey = "r"

    /// The name of the segment.
    @objc public let name: String?

    /// The list of segment rule conditions (has a logical AND relation between the items).
    @objc public let conditions: [UserCondition]

    init(name: String?, conditions: [UserCondition]) {
        self.name = name
        self.conditions = conditions
    }

    static func fromJson(json: [String: Any]) -> Segment {
        let conditions = json[self.conditionsKey] as? [[String: Any]] ?? []
        
        return Segment(name: json[self.nameKey] as? String,
                       conditions: conditions.map { cond in
                           .fromJson(json: cond)
                       })
    }

    func toJsonMap() -> [String: Any] {
        [
            Segment.nameKey: name as Any,
            Segment.conditionsKey: conditions.map { cond in
                cond.toJsonMap()
            }
        ]
    }
}

public final class TargetingRule: NSObject, JsonSerializable, Sendable {
    static let valueKey = "s"
    static let conditionsKey = "c"
    static let percentageOptionsKey = "p"

    /// The value associated with the targeting rule or nil if the targeting rule has percentage options THEN part.
    @objc public let servedValue: ServedValue?

    /// The list of conditions that are combined with the AND logical operator.
    @objc public let conditions: [Condition]

    /// The list of percentage options associated with the targeting rule or empty if the targeting rule has a served value THEN part.
    @objc public let percentageOptions: [PercentageOption]

    init(servedValue: ServedValue?, conditions: [Condition], percentageOptions: [PercentageOption]) {
        self.servedValue = servedValue
        self.conditions = conditions
        self.percentageOptions = percentageOptions
    }

    static func fromJson(json: [String: Any], segments: [Segment]) -> TargetingRule {
        let conditions = json[self.conditionsKey] as? [[String: Any]] ?? []
        let percentageOptions = json[self.percentageOptionsKey] as? [[String: Any]] ?? []
        let servedValueJson = json[self.valueKey] as? [String: Any]
        
        return TargetingRule(servedValue: servedValueJson != nil ? .fromJson(json: servedValueJson!) : nil,
                             conditions: conditions.map { cond in
                                .fromJson(json: cond, segments: segments)
                             },
                             percentageOptions: percentageOptions.map { opt in
                                .fromJson(json: opt)
                             })
    }

    func toJsonMap() -> [String: Any] {
        var result: [String: Any] = [
            TargetingRule.conditionsKey: conditions.map { cond in
                cond.toJsonMap()
            },
        ]
        if let sv = servedValue {
            result[TargetingRule.valueKey] = sv.toJsonMap()
        } else {
            result[TargetingRule.percentageOptionsKey] = percentageOptions.map { opt in
                opt.toJsonMap()
            }
        }
        return result
    }
}

public final class Condition: NSObject, JsonSerializable, Sendable {
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

    static func fromJson(json: [String: Any], segments: [Segment]) -> Condition {
        if let cond = json[self.userKey] as? [String: Any] {
            return Condition(userCondition: .fromJson(json: cond), segmentCondition: nil, prerequisiteFlagCondition: nil)
        }
        if let cond = json[self.segmentKey] as? [String: Any] {
            return Condition(userCondition: nil, segmentCondition: .fromJson(json: cond, segments: segments), prerequisiteFlagCondition: nil)
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

public final class UserCondition: NSObject, JsonSerializable, Sendable {
    static let stringListMaxLength = 10
    static let comparatorKey = "c"
    static let comparisonAttributeKey = "a"
    static let stringValKey = "s"
    static let doubleValKey = "d"
    static let stringArrValKey = "l"

    /// The value that the User Object attribute is compared to, when the comparator works with a single text comparison value.
    @objc public let stringValue: String?
    
    /// The value that the User Object attribute is compared to, when the comparator works with a numeric comparison value.
    public let doubleValue: Double?
    
    /// The value in Objective-C format that the User Object attribute is compared to, when the comparator works with a numeric comparison value.
    @objc public let doubleValueObjC: NSNumber?
    
    /// The value that the User Object attribute is compared to, when the comparator works with an array of text comparison value.
    @objc public let stringArrayValue: [String]?

    /// The operator which defines the relation between the comparison attribute and the comparison value.
    @objc public let comparator: UserComparator

    /// The User Object attribute that the condition is based on. Can be "Identifier", "Email", "Country" or any custom attribute.
    @objc public let comparisonAttribute: String?

    init(stringValue: String?, doubleValue: Double?, stringArrayValue: [String]?, comparator: UserComparator, comparisonAttribute: String?) {
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
                      comparator: UserComparator(rawValue: (json[self.comparatorKey] as? Int ?? -1)) ?? .unknown,
                      comparisonAttribute: json[self.comparisonAttributeKey] as? String)
    }

    func toJsonMap() -> [String: Any] {
        [
            UserCondition.stringValKey: stringValue as Any,
            UserCondition.doubleValKey: doubleValue as Any,
            UserCondition.stringArrValKey: stringArrayValue as Any,
            UserCondition.comparatorKey: comparator.rawValue,
            UserCondition.comparisonAttributeKey: comparisonAttribute as Any,
        ]
    }
    
    public override var description: String {
        let res = "User.\(unwrappedComparisonAttribute) \(comparatorTexts[comparator] ?? "<invalid comparator>") "
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
    
    var unwrappedComparisonAttribute: String {
        return comparisonAttribute ?? "<invalid attribute>"
    }
}

public final class SegmentCondition: NSObject, JsonSerializable, Sendable {
    static let indexKey = "s"
    static let comparatorKey = "c"

    /// Identifies the segment that the condition is based on.
    @objc public let index: Int

    /// The operator which defines the expected result of the evaluation of the segment.
    @objc public let segmentComparator: SegmentComparator
    
    let segment: Segment?

    init(index: Int, segmentComparator: SegmentComparator, segment: Segment? = nil) {
        self.index = index
        self.segmentComparator = segmentComparator
        self.segment = segment
    }

    static func fromJson(json: [String: Any], segments: [Segment]) -> SegmentCondition {
        let index = json[self.indexKey] as? Int ?? -1
        return SegmentCondition(index: index,
                                segmentComparator: SegmentComparator(rawValue: (json[self.comparatorKey] as? Int ?? -1)) ?? .unknown,
                                segment: segments.indices.contains(index) ? segments[index] : nil)
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

public final class PrerequisiteFlagCondition: NSObject, JsonSerializable, Sendable {
    static let flagKeyKey = "f"
    static let comparatorKey = "c"
    static let valueKey = "v"

    /// The key of the prerequisite flag that the condition is based on.
    @objc public let flagKey: String?

    /// The operator which defines the relation between the evaluated value of the prerequisite flag and the comparison value.
    @objc public let prerequisiteComparator: PrerequisiteFlagComparator
    
    /// The evaluated value of the prerequisite flag is compared to.
    @objc public let flagValue: SettingValue

    init(flagKey: String?, prerequisiteComparator: PrerequisiteFlagComparator, flagValue: SettingValue) {
        self.flagKey = flagKey
        self.prerequisiteComparator = prerequisiteComparator
        self.flagValue = flagValue
    }

    static func fromJson(json: [String: Any]) -> PrerequisiteFlagCondition {
        PrerequisiteFlagCondition(flagKey: json[self.flagKeyKey] as? String,
                                  prerequisiteComparator: PrerequisiteFlagComparator(rawValue: (json[self.comparatorKey] as? Int ?? -1)) ?? .unknown,
                                  flagValue: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]))
    }

    func toJsonMap() -> [String: Any] {
        [
            PrerequisiteFlagCondition.flagKeyKey: flagKey as Any,
            PrerequisiteFlagCondition.comparatorKey: prerequisiteComparator.rawValue,
            PrerequisiteFlagCondition.valueKey: flagValue.toJsonMap()
        ]
    }
    
    public override var description: String {
        return "Flag '\(flagKey ?? "<invalid key>")' \(prerequisiteComparator.text) '\(flagValue.anyValue ?? "<invalid value>")'"
    }
}

public enum ScalarValue: Equatable, Sendable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)

    var anyValue: Any {
        switch self {
        case .bool(let value): return value
        case .string(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        }
    }

    public func asBool() -> Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }
    
    public func asString() -> String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    public func asInt() -> Int? {
        if case let .int(value) = self {
            return value
        }
        return nil
    }

    public func asDouble() -> Double? {
        if case let .double(value) = self {
            return value
        }
        return nil
    }
}

enum ValueResult {
    case success(ScalarValue)
    case error(String)
}

private struct InvalidSettingValue: Sendable {
    let description: String
    let type: String
}

public final class SettingValue: NSObject, JsonSerializable, Sendable {
    static let boolKey = "b"
    static let stringKey = "s"
    static let doubleKey = "d"
    static let intKey = "i"
    
    static let settingValueMissingMessage = "Setting value is missing"
    
    /// Holds the feature flag's value.
    public let value: ScalarValue?
    
    @objc public let boolValueObjC: NSNumber?
    
    /// Holds a string setting's value.
    @objc public let stringValue: String?
    
    @objc public let doubleValueObjC: NSNumber?
    
    @objc public let intValueObjC: NSNumber?
    
    private let invalidValue: InvalidSettingValue?
    
    init(value: ScalarValue?, invalidValue: Any? = nil) {
        self.value = value
        self.invalidValue = invalidValue.map { InvalidSettingValue(description: "\($0)", type: "\(type(of: $0))") }
        
        if case let .bool(val)? = value {
            self.boolValueObjC = NSNumber(value: val)
        } else {
            self.boolValueObjC = nil
        }
        if case let .string(val)? = value {
            self.stringValue = val
        } else {
            self.stringValue = nil
        }
        if case let .double(val)? = value {
            self.doubleValueObjC = NSNumber(value: val)
        } else {
            self.doubleValueObjC = nil
        }
        if case let .int(val)? = value {
            self.intValueObjC = NSNumber(value: val)
        } else {
            self.intValueObjC = nil
        }
    }
    
    convenience init(invalidValue: Any?) {
        self.init(value: nil, invalidValue: invalidValue)
    }
    
    static func fromJson(json: [String: Any]) -> SettingValue {
        SettingValue(value: (json[self.boolKey] as? Bool).map { ScalarValue.bool($0) } ??
                           (json[self.stringKey] as? String).map { ScalarValue.string($0) } ??
                           (json[self.doubleKey] as? Double).map { ScalarValue.double($0) } ??
                           (json[self.intKey] as? Int).map { ScalarValue.int($0) })
    }
    
    func toJsonMap() -> [String: Any] {
        [
            SettingValue.boolKey: value?.asBool() as Any,
            SettingValue.stringKey: value?.asString() as Any,
            SettingValue.doubleKey: value?.asDouble() as Any,
            SettingValue.intKey: value?.asInt() as Any,
        ]
    }
    
    static func fromAnyValue(value: Any?) -> SettingValue {
        switch value {
        case let val as String:
            return SettingValue(value: .string(val))
        case let val as Bool:
            return SettingValue(value: .bool(val))
        case let val as Double:
            return SettingValue(value: .double(val))
        case let val as Int:
            return SettingValue(value: .int(val))
        default:
            return SettingValue(invalidValue: value)
        }
    }
    
    var settingType: SettingType {
        switch value {
        case .bool: return .bool
        case .string: return .string
        case .double: return .double
        case .int: return .int
        default: return .unknown
        }
    }
    
    var anyValue: Any? {
        value?.anyValue ?? invalidValue?.description
    }
    
    var isValid: Bool {
        return value != nil
    }
    
    var isEmpty: Bool {
        return !isValid && invalidValue == nil
    }
    
    func toCheckedValue(settingType: SettingType) -> ValueResult {
        if isEmpty {
            return .error(SettingValue.settingValueMissingMessage)
        }
        if let inv = invalidValue {
            return .error("Setting value '\(inv.description)' is of an unsupported type (\(inv.type)")
        }
        switch settingType {
        case .bool:
            guard let val = value?.asBool() else {
                return .error(SettingValue.settingValueMissingMessage)
            }
            return .success(.bool(val))
        case .string:
            guard let val = value?.asString() else {
                return .error(SettingValue.settingValueMissingMessage)
            }
            return .success(.string(val))
        case .int:
            guard let val = value?.asInt() else {
                return .error(SettingValue.settingValueMissingMessage)
            }
            return .success(.int(val))
        case .double:
            guard let val = value?.asDouble() else {
                return .error(SettingValue.settingValueMissingMessage)
            }
            return .success(.double(val))
        default:
            return .error("Setting value is missing or invalid")
        }
    }
}

public final class ServedValue: NSObject, JsonSerializable, Sendable {
    static let valueKey = "v"
    static let idKey = "i"

    /// The value associated with the targeting rule.
    @objc public let value: SettingValue
    
    /// Variation ID (for analytical purposes).
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


public final class PercentageOption: NSObject, JsonSerializable, Sendable {
    static let valueKey = "v"
    static let percentageKey = "p"
    static let variationIdKey = "i"

    /// The served value of the percentage option.
    @objc public let servedValue: SettingValue

    /// A number between 0 and 100 that represents a randomly allocated fraction of the users.
    @objc public let percentage: Int

    /// Variation ID (for analytical purposes).
    @objc public let variationId: String?

    init(servedValue: SettingValue, percentage: Int, variationId: String?) {
        self.servedValue = servedValue
        self.percentage = percentage
        self.variationId = variationId;
    }

    static func fromJson(json: [String: Any]) -> PercentageOption {
        PercentageOption(servedValue: .fromJson(json: json[self.valueKey] as? [String: Any] ?? [:]),
                percentage: json[self.percentageKey] as? Int ?? 0,
                variationId: json[self.variationIdKey] as? String)
    }

    func toJsonMap() -> [String: Any] {
        [
            PercentageOption.valueKey: servedValue.toJsonMap(),
            PercentageOption.percentageKey: percentage,
            PercentageOption.variationIdKey: variationId as Any
        ]
    }
}
