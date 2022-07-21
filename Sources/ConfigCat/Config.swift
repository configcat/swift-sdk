import Foundation

struct ConfigEntry: Equatable {
    static func == (lhs: ConfigEntry, rhs: ConfigEntry) -> Bool {
        lhs.jsonString == rhs.jsonString && lhs.eTag == rhs.eTag
    }

    let jsonString: String
    let config: Config
    let eTag: String
    let fetchTime: Date

    init(jsonString: String = "", config: Config = Config.empty, eTag: String = "", fetchTime: Date = Date.distantPast) {
        self.jsonString = jsonString
        self.config = config
        self.eTag = eTag
        self.fetchTime = fetchTime
    }

    func withFetchTime(time: Date) -> ConfigEntry {
        ConfigEntry(jsonString: jsonString, config: config, eTag: eTag, fetchTime: time)
    }

    var isEmpty: Bool {
        get {
            self == .empty
        }
    }

    static let empty = ConfigEntry()
}

struct Config {
    static let value = "v"
    static let comparator = "t"
    static let comparisonAttribute = "a"
    static let comparisonValue = "c"
    static let rolloutPercentageItems = "p"
    static let percentage = "p"
    static let rolloutRules = "r"
    static let variationId = "i"
    static let preferences = "p"
    static let preferencesUrl = "u"
    static let preferencesRedirect = "r"
    static let entries = "f"

    let preferences: [String: Any]
    let entries: [String: Any]

    init(preferences: [String: Any] = [:], entries: [String: Any] = [:]) {
        self.preferences = preferences
        self.entries = entries
    }

    var isEmpty: Bool {
        get {
            entries.isEmpty && preferences.isEmpty
        }
    }
    static let empty = Config()
}
