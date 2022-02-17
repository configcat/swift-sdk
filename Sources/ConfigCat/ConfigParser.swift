import Foundation
import os.log

enum ParserError: Error {
    case parseFailure
    case invalidRequestedType
}

/// A json parser which can be used to deserialize configuration json strings.
final class ConfigParser {
    fileprivate let log: Logger
    fileprivate let evaluator: RolloutEvaluator
    
    public init(logger: Logger, evaluator: RolloutEvaluator) {
        self.log = logger
        self.evaluator = evaluator
    }
    
    /**
     Parses a json element identified by the `key` from the given json
     string into a primitive type (Boolean, Double, Integer or String).
     
     - Parameter for: the key of the value.
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.invalidRequestedType` when the `Value` type is not supported.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func getValueFromSettings<Value>(settings: [String: Any], key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
        if Value.self != String.self &&
            Value.self != String?.self &&
            Value.self != Int.self &&
            Value.self != Int?.self &&
            Value.self != Double.self &&
            Value.self != Double?.self &&
            Value.self != Bool.self &&
            Value.self != Bool?.self &&
            Value.self != Any.self &&
            Value.self != Any?.self {
            self.log.error(message: "Only String, Integer, Double, Bool or Any types are supported.")
            return defaultValue
        }

        if settings.isEmpty {
            self.log.error(message: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)");
            return defaultValue
        }

        let (value, _, evaluateLog): (Value?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            self.log.info(message: "%@", evaluateLog)
        }
        if let value = value {
            return value
        }

        self.log.error(message: """
                                Evaluating the value for the key '%@' failed.
                                Returning defaultValue: [%@].
                                Here are the available keys: %@
                                """, key, "\(defaultValue)", [String](settings.keys))

        return defaultValue
    }

    /**
     Parse the Variation ID (analytics) of a feature flag or setting based on it's key from the given json.
     
     - Parameter for: the key of the value.
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func getVariationIdFromSettings(settings: [String: Any], key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            self.log.info(message: "%@", evaluateLog)
        }
        if let variationId = variationId {
            return variationId
        }

        self.log.error(message: """
               Evaluating the variation id for the key '%@' failed.
               Returning defaultVariationId: [%@]
               Here are the available keys: %@
               """, key, "\(defaultVariationId)", [String](settings.keys))

        return defaultVariationId
    }
    
    /**
     Gets the Variation IDs (analytics) of all feature flags or settings from the config json.
     
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func getAllVariationIdsFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String] {
        var variationIds = [String]()
        for key in settings.keys {
            let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let variationId = variationId {
                variationIds.append(variationId)
            } else {
                self.log.error(message: "Evaluating the variation id for the key '%@' failed.", key)
            }
        }
        return variationIds
    }

    public func getAllValuesFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String: Any] {
        var allValues = [String: Any]()
        for key in settings.keys {
            let (value, _, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let value = value {
                allValues[key] = value
            } else {
                self.log.error(message: "Evaluating the value for the key '%@' failed.", key)
            }
        }
        return allValues
    }
    
    public func getKeyAndValueFromSettings(settings: [String: Any], variationId: String) -> KeyValue? {
        for (key, json) in settings {
            if let json = json as? [String: Any], let value = json[Config.value] {
                if variationId == json[Config.variationId] as? String {
                    return KeyValue(key: key, value: value)
                }

                let rolloutRules = json[Config.rolloutRules] as? [[String: Any]] ?? []
                for rule in rolloutRules {
                    if variationId == rule[Config.variationId] as? String, let value = json[Config.value]  {
                        return KeyValue(key: key, value: value)
                    }
                }

                let rolloutPercentageItems = json[Config.rolloutPercentageItems] as? [[String: Any]] ?? []
                for rule in rolloutPercentageItems {
                    if variationId == rule[Config.variationId] as? String, let value = json[Config.value] {
                        return KeyValue(key: key, value: value)
                    }
                }
            }
        }

        self.log.error(message: "Could not find the setting for the given variationId: '%@'", variationId);
        return nil
    }
}
