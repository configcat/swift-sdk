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

extension Equatable {
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

class Constants {
    static let version: String = "11.0.1"
    static let configJsonName: String = "config_v6.json"
    static let configJsonCacheVersion: String = "v2"
    static let globalBaseUrl: String = "https://cdn-global.configcat.com"
    static let euOnlyBaseUrl: String = "https://cdn-eu.configcat.com"
    static let proxyPrefix: String = "configcat-proxy/"
    static let sdkKeyCompSize: Int = 22
}

class Utils {
    public static func generateCacheKey(sdkKey: String) -> String {
        let keyToHash = sdkKey + "_" + Constants.configJsonName + "_" + Constants.configJsonCacheVersion
        return String(keyToHash.sha1hex)
    }
    
    static func validateSdkKey(sdkKey: String, isCustomUrl: Bool) -> Bool {
        if isCustomUrl && sdkKey.count > Constants.proxyPrefix.count && sdkKey.hasPrefix(Constants.proxyPrefix) {
            return true
        }
        let comps = sdkKey.split(separator: "/")
        switch comps.count {
        case 2:
            return comps[0].count == Constants.sdkKeyCompSize && comps[1].count == Constants.sdkKeyCompSize
        case 3:
            return comps[0] == "configcat-sdk-1" && comps[1].count == Constants.sdkKeyCompSize && comps[2].count == Constants.sdkKeyCompSize
        default:
            return false
        }
    }
    
    static func anyEq(a: Any?, b: Any?) -> Bool {
        if a == nil && b == nil {
            return true
        }
        guard let eq1 = a as? any Equatable, let eq2 = b as? any Equatable else {
            return false
        }
        return eq1.isEqual(eq2)
    }
    
    static func toJson(obj: Any) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: obj, options: [])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    static func fromJson<T>(json: String) -> T? {
        do {
            guard let data = json.data(using: .utf8) else {
                return nil
            }
            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? T else {
                return nil
            }
            return result
        } catch {
            return nil
        }
    }
}
