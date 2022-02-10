import Foundation
import os.log

class ConfigJsonCache {
    private var config: Config? = nil
    private let log: Logger

    public init(logger: Logger) {
        self.log = logger
    }

    public func getConfigFromJson(json: String) -> Config? {
        if json.isEmpty {
            return nil
        }

        if let config = self.config {
            if config.jsonString == json {
                return config
            }
        }

        do {
            guard let data = json.data(using: .utf8) else {return nil}
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {return nil}
            self.config = Config(jsonString: json, preferences: jsonObject[Config.preferences] as? [String: Any] ?? [:], entries: jsonObject[Config.entries] as? [String: Any] ?? [:])
            return self.config
        } catch {
            self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
            return nil
        }
    }
}


