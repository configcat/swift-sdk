import Foundation
@testable import ConfigCat

extension String {
    func toEntryFromConfigString() -> ConfigEntry {
        let data = data(using: .utf8)!
        let jsonObject = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        let config = Config.fromJson(json: jsonObject)
        return ConfigEntry(config: config)
    }
}

extension ConfigEntry {
    func toJsonString() -> String {
        let jsonMap = toJsonMap()
        let json = try! JSONSerialization.data(withJSONObject: jsonMap, options: [])
        return String(data: json, encoding: .utf8)!
    }
}
