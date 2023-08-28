import Foundation

struct ParseError: Error, CustomStringConvertible {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var description: String {
        get {
            message
        }
    }
}

class Weak<T: AnyObject> {
    weak private var value: T?

    init(value: T) {
        self.value = value
    }

    func get() -> T? {
        value
    }
}

extension Date {
    func add(years: Int = 0, months: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
        let comp = DateComponents(year: years, month: months, day: days, hour: hours, minute: minutes, second: seconds)
        return Calendar.current.date(byAdding: comp, to: self)
    }

    func subtract(years: Int = 0, months: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
        add(years: -years, months: -months, days: -days, hours: -hours, minutes: -minutes, seconds: -seconds)
    }
}

class Constants {
    static let version: String = "10.0.0"
    static let configJsonName: String = "config_v5.json"
    static let configJsonCacheVersion: String = "v2"
    static let globalBaseUrl: String = "https://cdn-global.configcat.com"
    static let euOnlyBaseUrl: String = "https://cdn-eu.configcat.com"
}

class Utils {
    public static func generateCacheKey(sdkKey: String) -> String {
        let keyToHash = sdkKey + "_" + Constants.configJsonName + "_" + Constants.configJsonCacheVersion
        return String(keyToHash.sha1hex ?? keyToHash)
    }
}
