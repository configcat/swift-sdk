import Foundation

class ConfigEntry: Equatable {
    static func ==(lhs: ConfigEntry, rhs: ConfigEntry) -> Bool {
        lhs.eTag == rhs.eTag
    }

    let config: Config
    let eTag: String
    let fetchTime: Date

    init(config: Config = Config.empty, eTag: String = "", fetchTime: Date = .distantPast) {
        self.config = config
        self.eTag = eTag
        self.fetchTime = fetchTime
    }

    func withFetchTime(time: Date) -> ConfigEntry {
        ConfigEntry(config: config, eTag: eTag, fetchTime: time)
    }

    static func fromJson(json: [String: Any]) -> ConfigEntry {
        let eTag = json["eTag"] as? String ?? ""
        var config: Config = .empty
        var fetchTime: Date = .distantPast
        if let configFromMap = json["config"] as? [String: Any] {
            config = Config.fromJson(json: configFromMap)
        }
        if let fetchIntervalSince1970 = json["fetchTime"] as? Double {
            fetchTime = Date(timeIntervalSince1970: fetchIntervalSince1970)
        }
        return ConfigEntry(config: config, eTag: eTag, fetchTime: fetchTime)
    }

    func toJsonMap() -> [String: Any] {
        [
            "eTag": eTag,
            "fetchTime": fetchTime.timeIntervalSince1970,
            "config": config.toJsonMap()
        ]
    }

    var isEmpty: Bool {
        get {
            self == .empty
        }
    }

    static let empty = ConfigEntry(eTag: "empty")
}

class Config {
    static let preferencesKey = "p"
    static let entriesKey = "f"

    let preferences: Preferences?
    let entries: [String: Setting]

    init(preferences: Preferences? = nil, entries: [String: Setting] = [:]) {
        self.preferences = preferences
        self.entries = entries
    }

    static func fromJson(json: [String: Any]) -> Config {
        let entriesMap = json[Config.entriesKey] as? [String: Any] ?? [:]
        let entries = entriesMap.mapValues { entry in Setting.fromJson(json: entry as? [String: Any] ?? [:]) }
        if let preferences = json[Config.preferencesKey] as? [String: Any] {
            return Config(preferences: Preferences.fromJson(json: preferences), entries: entries)
        }
        return Config(preferences: nil, entries: entries)
    }

    func toJsonMap() -> [String: Any] {
        var result: [String: Any] = [
            Config.entriesKey: entries.mapValues { setting in setting.toJsonMap() },
        ]
        if let pref = preferences {
            result[Config.preferencesKey] = pref.toJsonMap()
        }
        return result
    }

    var isEmpty: Bool {
        get {
            entries.isEmpty
        }
    }
    static let empty = Config()
}

class Preferences {
    static let preferencesUrlKey = "u"
    static let preferencesRedirectKey = "r"

    let preferencesUrl: String
    let preferencesRedirect: Int

    init(preferencesUrl: String, preferencesRedirect: Int) {
        self.preferencesUrl = preferencesUrl
        self.preferencesRedirect = preferencesRedirect
    }

    static func fromJson(json: [String: Any]) -> Preferences {
        Preferences(preferencesUrl: json[Preferences.preferencesUrlKey] as? String ?? "",
                preferencesRedirect: json[Preferences.preferencesRedirectKey] as? Int ?? 0)
    }

    func toJsonMap() -> [String: Any] {
        [
            Preferences.preferencesUrlKey: preferencesUrl,
            Preferences.preferencesRedirectKey: preferencesRedirect,
        ]
    }
}

public final class Setting: NSObject {
    static let valueKey = "v"
    static let percentageItemsKey = "p"
    static let rolloutRulesKey = "r"
    static let variationIdKey = "i"

    /// Value of the feature flag / setting.
    @objc public let value: Any

    /// Collection of percentage rules that belongs to the feature flag / setting.
    @objc public let percentageItems: [PercentageRule]

    /// Collection of targeting rules that belongs to the feature flag / setting.
    @objc public let rolloutRules: [RolloutRule]

    /// Variation ID (for analytical purposes).
    @objc public let variationId: String

    init(value: Any, variationId: String, percentageItems: [PercentageRule], rolloutRules: [RolloutRule]) {
        self.value = value
        self.percentageItems = percentageItems
        self.rolloutRules = rolloutRules
        self.variationId = variationId;
    }

    static func fromJson(json: [String: Any]) -> Setting {
        let rolloutRules = json[Setting.rolloutRulesKey] as? [[String: Any]] ?? []
        let percentageRules = json[Setting.percentageItemsKey] as? [[String: Any]] ?? []

        return Setting(value: json[Setting.valueKey] ?? "",
                variationId: json[Setting.variationIdKey] as? String ?? "",
                percentageItems: percentageRules.map { rule in PercentageRule.fromJson(json: rule) },
                rolloutRules: rolloutRules.map { rule in RolloutRule.fromJson(json: rule) })
    }

    func toJsonMap() -> [String: Any] {
        [
            Setting.valueKey: value,
            Setting.variationIdKey: variationId,
            Setting.percentageItemsKey: percentageItems.map { rule in rule.toJsonMap() },
            Setting.rolloutRulesKey: rolloutRules.map { rule in rule.toJsonMap() },
        ]
    }
}

public final class RolloutRule: NSObject {
    static let valueKey = "v"
    static let comparatorKey = "t"
    static let comparisonAttributeKey = "a"
    static let comparisonValueKey = "c"
    static let variationIdKey = "i"

    /// Value served when the rule is selected during evaluation.
    @objc public let value: Any

    /// The rule's variation ID (for analytical purposes).
    @objc public let variationId: String

    /// The operator used in the comparison.
    ///
    /// 0  -> 'IS ONE OF',
    /// 1  -> 'IS NOT ONE OF',
    /// 2  -> 'CONTAINS',
    /// 3  -> 'DOES NOT CONTAIN',
    /// 4  -> 'IS ONE OF (SemVer)',
    /// 5  -> 'IS NOT ONE OF (SemVer)',
    /// 6  -> '< (SemVer)',
    /// 7  -> '<= (SemVer)',
    /// 8  -> '> (SemVer)',
    /// 9  -> '>= (SemVer)',
    /// 10 -> '= (Number)',
    /// 11 -> '<> (Number)',
    /// 12 -> '< (Number)',
    /// 13 -> '<= (Number)',
    /// 14 -> '> (Number)',
    /// 15 -> '>= (Number)',
    /// 16 -> 'IS ONE OF (Sensitive)',
    /// 17 -> 'IS NOT ONE OF (Sensitive)'
    @objc public let comparator: Int

    /// The user attribute used in the comparison during evaluation.
    @objc public let comparisonAttribute: String

    /// The comparison value compared to the given user attribute.
    @objc public let comparisonValue: String

    init(value: Any, variationId: String, comparator: Int, comparisonAttribute: String, comparisonValue: String) {
        self.value = value
        self.comparator = comparator
        self.comparisonAttribute = comparisonAttribute
        self.comparisonValue = comparisonValue
        self.variationId = variationId;
    }

    static func fromJson(json: [String: Any]) -> RolloutRule {
        RolloutRule(value: json[RolloutRule.valueKey] ?? "",
                variationId: json[RolloutRule.variationIdKey] as? String ?? "",
                comparator: json[RolloutRule.comparatorKey] as? Int ?? 0,
                comparisonAttribute: json[RolloutRule.comparisonAttributeKey] as? String ?? "",
                comparisonValue: json[RolloutRule.comparisonValueKey] as? String ?? "")
    }

    func toJsonMap() -> [String: Any] {
        [
            RolloutRule.valueKey: value,
            RolloutRule.variationIdKey: variationId,
            RolloutRule.comparatorKey: comparator,
            RolloutRule.comparisonAttributeKey: comparisonAttribute,
            RolloutRule.comparisonValueKey: comparisonValue
        ]
    }
}

public final class PercentageRule: NSObject {
    static let valueKey = "v"
    static let percentageKey = "p"
    static let variationIdKey = "i"

    /// Value served when the rule is selected during evaluation.
    @objc public let value: Any

    /// The rule's percentage value.
    @objc public let percentage: Int

    /// The rule's variation ID (for analytical purposes).
    @objc public let variationId: String

    init(value: Any, percentage: Int, variationId: String) {
        self.value = value
        self.percentage = percentage
        self.variationId = variationId;
    }

    static func fromJson(json: [String: Any]) -> PercentageRule {
        PercentageRule(value: json[PercentageRule.valueKey] ?? "",
                percentage: json[PercentageRule.percentageKey] as? Int ?? 0,
                variationId: json[PercentageRule.variationIdKey] as? String ?? "")
    }

    func toJsonMap() -> [String: Any] {
        [
            PercentageRule.valueKey: value,
            PercentageRule.percentageKey: percentage,
            PercentageRule.variationIdKey: variationId
        ]
    }
}
