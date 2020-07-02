import Foundation
import os.log

enum ParserError: Error {
    case parseFailure
    case invalidRequestedType
}

/// A json parser which can be used to deserialize configuration json strings.
public final class ConfigParser {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigParser.self).bundleIdentifier!, category: "Config Parser")
    fileprivate let evaluator = RolloutEvaluator()

    /**
     Parses a json element identified by the `key` from the given json
     string into a primitive type (Boolean, Double, Integer or String).
     
     - Parameter for: the key of the value.
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.invalidRequestedType` when the `Value` type is not supported.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func parseValue<Value>(for key: String, json: String, user: User? = nil) throws -> Value {
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
            os_log("Only String, Integer, Double, Bool or Any types can be parsed.", log: ConfigParser.log, type: .error)
            throw ParserError.invalidRequestedType
        }
        
        if let data = json.data(using: .utf8) {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let value: Value = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user).value {
                    return value
                } else {
                    os_log("""
                        Parsing the json value for the key '%@' failed.
                        Returning defaultValue.
                        Here are the available keys: %@
                        """, log: ConfigParser.log, type: .error, key, [String](jsonObject.keys))
                }
            }
        }
        
        throw ParserError.parseFailure
    }
    
    /**
     Gets all setting keys from the config json.
     
     - Parameter json: the json config.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func getAllKeys(json: String) throws -> [String] {
        if let data = json.data(using: .utf8) {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return [String](jsonObject.keys)
            }
        }
        
        os_log("Parsing the json failed.", log: ConfigParser.log, type: .error)
        throw ParserError.parseFailure
    }

    /**
     Parse the Variation ID (analytics) of a feature flag or setting based on it's key from the given json.

     - Parameter for: the key of the value.
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func parseVariationId(for key: String, json: String, user: User? = nil) throws -> String {
        if let data = json.data(using: .utf8) {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let (_, variationId): (Any?, String?) = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user)
                if let variationId = variationId {
                    return variationId
                } else {
                    os_log("""
                           Parsing the variation id for the key '%@' failed.
                           Returning defaultValue.
                           Here are the available keys: %@
                           """, log: ConfigParser.log, type: .error, key, [String](jsonObject.keys))
                }
            }
        }

        throw ParserError.parseFailure
    }

    /**
     Gets the Variation IDs (analytics) of all feature flags or settings from the config json.

     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func getAllVariationIds(json: String, user: User? = nil) throws -> [String] {
        if let data = json.data(using: .utf8) {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                var variationIds = [String]()
                for key in jsonObject.keys {
                    let (_, variationId): (Any?, String?) = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user)
                    if let variationId = variationId {
                        variationIds.append(variationId)
                    } else {
                        os_log("""
                               Parsing the variation id for the key '%@' failed.
                               """, log: ConfigParser.log, type: .error, key)
                    }
                }
                return variationIds
            }
        }

        os_log("Parsing the json failed.", log: ConfigParser.log, type: .error)
        throw ParserError.parseFailure
    }

    public func getKeyAndValue(for variationId: String, json: String) throws -> (key: String, value: Any) {
        if let data = json.data(using: .utf8) {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                for (key, json) in jsonObject {
                    if let json = json as? [String: Any], let value = json[Config.value] {
                        if variationId == json[Config.variationId] as? String {
                            return (key, value)
                        }

                        let rolloutRules = json[Config.rolloutRules] as? [[String: Any]] ?? []
                        for rule in rolloutRules {
                            if variationId == rule[Config.variationId] as? String, let value = json[Config.value]  {
                                return (key, value)
                            }
                        }

                        let rolloutPercentageItems = json[Config.rolloutPercentageItems] as? [[String: Any]] ?? []
                        for rule in rolloutPercentageItems {
                            if variationId == rule[Config.variationId] as? String, let value = json[Config.value] {
                                return (key, value)
                            }
                        }
                    }
                }

                os_log("Could not find the setting for the given variationId: '%@'", log: ConfigParser.log, type: .error, variationId);
            }
        }

        throw ParserError.parseFailure
    }

}
