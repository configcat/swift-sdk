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
    public func parseValue<Value>(for key: String, json: String, user: ConfigCatUser? = nil) throws -> Value {
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
            self.log.error(message: "Only String, Integer, Double, Bool or Any types can be parsed.")
            throw ParserError.invalidRequestedType
        }
        
        if let jsonObject = try ConfigParser.parseEntries(json: json) {
            let (value, _, evaluateLog): (Value?, String?, String?) = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let value = value {
                return value
            } else {
                self.log.error(message: """
                        Parsing the json value for the key '%@' failed.
                        Returning defaultValue.
                        Here are the available keys: %@
                        """, key, [String](jsonObject.keys))
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
        if let jsonObject = try ConfigParser.parseEntries(json: json) {
            return [String](jsonObject.keys)
        }
        
        self.log.error(message: "Parsing the json failed.")
        throw ParserError.parseFailure
    }
    
    /**
     Parse the Variation ID (analytics) of a feature flag or setting based on it's key from the given json.
     
     - Parameter for: the key of the value.
     - Parameter json: the json config.
     - Parameter user: the user object to identify the caller.
     - Throws: `ParserError.parseFailure` when the parsing failed.
     */
    public func parseVariationId(for key: String, json: String, user: ConfigCatUser? = nil) throws -> String {
        if let jsonObject = try ConfigParser.parseEntries(json: json) {
            let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let variationId = variationId {
                return variationId
            } else {
                self.log.error(message: """
                       Parsing the variation id for the key '%@' failed.
                       Returning defaultValue.
                       Here are the available keys: %@
                       """, key, [String](jsonObject.keys))
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
    public func getAllVariationIds(json: String, user: ConfigCatUser? = nil) throws -> [String] {
        if let jsonObject = try ConfigParser.parseEntries(json: json) {
            var variationIds = [String]()
            for key in jsonObject.keys {
                let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user)
                if let evaluateLog = evaluateLog {
                    self.log.info(message: "%@", evaluateLog)
                }
                if let variationId = variationId {
                    variationIds.append(variationId)
                } else {
                    self.log.error(message: """
                               Parsing the variation id for the key '%@' failed.
                               """, key)
                }
            }
            return variationIds
        }
        
        self.log.error(message: "Parsing the json failed.")
        throw ParserError.parseFailure
    }
    
    public func getKeyAndValue(for variationId: String, json: String) throws -> (key: String, value: Any) {
        if let jsonObject = try ConfigParser.parseEntries(json: json) {
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
        }
        
        self.log.error(message: "Could not find the setting for the given variationId: '%@'", variationId);
        
        throw ParserError.parseFailure
    }
    
    private class func parseEntries(json: String) throws -> [String: Any]? {
        guard let data = json.data(using: .utf8) else {return nil}
        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {return nil}
        return jsonObject[Config.entries] as? [String: Any]
    }
    
    internal class func parsePreferences(json: String) throws -> [String: Any]? {
        guard let data = json.data(using: .utf8) else {return nil}
        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {return nil}
        return jsonObject[Config.preferences] as? [String: Any]
    }
}
