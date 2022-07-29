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

extension String {
    func parseConfigFromJson() -> Result<Config, Error> {
        do {
            guard let data = data(using: .utf8) else {
                return .failure(ParseError(message: "Decode to utf8 data failed."))
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return .failure(ParseError(message: "Convert to [String: Any] map failed."))
            }
            return .success(Config(preferences: jsonObject[Config.preferences] as? [String: Any] ?? [:], entries: jsonObject[Config.entries] as? [String: Any] ?? [:]))
        } catch {
            return .failure(error)
        }
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
    static let version: String = "9.0.1"
    static let configJsonName: String = "config_v5"
    static let globalBaseUrl: String = "https://cdn-global.configcat.com"
    static let euOnlyBaseUrl: String = "https://cdn-eu.configcat.com"
}