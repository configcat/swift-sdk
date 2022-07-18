import Foundation
import os.log

class ConfigJsonCache {
    var config: Config = .empty
    private let log: Logger

    init(logger: Logger) {
        self.log = logger
    }

    func getConfigFromJson(json: String) -> Config {
        if json.isEmpty {
            return .empty
        }

        if self.config.jsonString == json {
            return self.config
        }

        do {
            guard let data = json.data(using: .utf8) else {return .empty}
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {return .empty}
            return Config(jsonString: json, preferences: jsonObject[Config.preferences] as? [String: Any] ?? [:], entries: jsonObject[Config.entries] as? [String: Any] ?? [:])
        } catch {
            self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
            return .empty
        }
    }
}


