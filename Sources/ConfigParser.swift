import Foundation
import os.log

enum ParserError: Error {
    case parseFailure
    case invalidRequestedType
}

public final class ConfigParser {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigParser.self).bundleIdentifier!, category: "Config Parser")
    fileprivate let decoder = JSONDecoder()
    
    public func parse<Value: Decodable>(json: String) throws -> Value {
        if let data = json.data(using: .utf8) {
            return try decoder.decode(Value.self, from: data)
        }
        
        os_log("Parsing of the given json failed. %@", log: ConfigParser.log, type: .error, json)
        throw ParserError.parseFailure
    }
    
    public func parseValue<Value>(for key: String, json: String) throws -> Value {
        if Value.self != String.self && Value.self != Int.self && Value.self != Double.self && Value.self != Bool.self {
            os_log("Only String, Integer, Double or Boolean types can be parsed.", log: ConfigParser.log, type: .error)
            throw ParserError.invalidRequestedType
        }
        
        if let data = json.data(using: .utf8) {
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let value = dict[key] as? Value {
                    return value
                }
            }
        }
        
        os_log("Parsing the json value for the key '%@' failed.", log: ConfigParser.log, type: .error, key)
        throw ParserError.parseFailure
    }
}
