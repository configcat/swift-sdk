import Foundation
import os.log

enum ParserError: Error {
    case parseFailure
    case invalidRequestedType
}

/// A json parser which can be used to deserialize configuration json strings.
public final class ConfigParser {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigParser.self).bundleIdentifier ?? "", category: "Config Parser")
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
                if let value: Value = self.evaluator.evaluate(json: jsonObject[key], key: key, user: user) {
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
}
