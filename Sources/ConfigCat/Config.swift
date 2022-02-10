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

    let jsonString: String
    let preferences: [String: Any]
    let entries: [String: Any]

    init(jsonString: String = "{}", preferences: [String: Any] = [:], entries: [String: Any] = [:]) {
        self.jsonString = jsonString
        self.preferences = preferences
        self.entries = entries
    }
}
