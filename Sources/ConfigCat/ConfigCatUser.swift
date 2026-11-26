import Foundation
import CoreFoundation

#if SWIFT_PACKAGE
import Version
#endif

enum UserAttribute: Sendable {
    case string(String)
    case strings([String])
    case bool(Bool)
    case int(Int)
    case int8(Int8)
    case int16(Int16)
    case int32(Int32)
    case int64(Int64)
    case uint(UInt)
    case uint8(UInt8)
    case uint16(UInt16)
    case uint32(UInt32)
    case uint64(UInt64)
    case float(Float)
    case double(Double)
    case date(Date)
    case number(NSNumber)
    case unsupported(String)

    init(_ value: Any) {
        if type(of: value) is NSNumber.Type, let number = value as? NSNumber {
            if let snapshot = Self.snapshot(number: number) {
                self = .number(snapshot)
            } else {
                self = .unsupported("\(value)")
            }
            return
        }

        switch value {
        case let value as String: self = .string(value)
        case let value as [String]: self = .strings(value)
        case let value as Bool: self = .bool(value)
        case let value as Int: self = .int(value)
        case let value as Int8: self = .int8(value)
        case let value as Int16: self = .int16(value)
        case let value as Int32: self = .int32(value)
        case let value as Int64: self = .int64(value)
        case let value as UInt: self = .uint(value)
        case let value as UInt8: self = .uint8(value)
        case let value as UInt16: self = .uint16(value)
        case let value as UInt32: self = .uint32(value)
        case let value as UInt64: self = .uint64(value)
        case let value as Float: self = .float(value)
        case let value as Double: self = .double(value)
        case let value as Date: self = .date(value)
        default: self = .unsupported("\(value)")
        }
    }

    private static func snapshot(number: NSNumber) -> NSNumber? {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return NSNumber(value: number.boolValue)
        }
        if let decimal = number as? NSDecimalNumber {
            return NSDecimalNumber(decimal: decimal.decimalValue)
        }
        switch String(cString: number.objCType) {
        case "c": return NSNumber(value: number.int8Value)
        case "s": return NSNumber(value: number.int16Value)
        case "i": return NSNumber(value: number.int32Value)
        case "l", "q": return NSNumber(value: number.int64Value)
        case "C": return NSNumber(value: number.uint8Value)
        case "S": return NSNumber(value: number.uint16Value)
        case "I": return NSNumber(value: number.uint32Value)
        case "L", "Q": return NSNumber(value: number.uint64Value)
        case "f": return NSNumber(value: number.floatValue)
        case "d": return NSNumber(value: number.doubleValue)
        default: return nil
        }
    }

    var anyValue: Any {
        switch self {
        case .string(let value): return value
        case .strings(let value): return value
        case .bool(let value): return value
        case .int(let value): return value
        case .int8(let value): return value
        case .int16(let value): return value
        case .int32(let value): return value
        case .int64(let value): return value
        case .uint(let value): return value
        case .uint8(let value): return value
        case .uint16(let value): return value
        case .uint32(let value): return value
        case .uint64(let value): return value
        case .float(let value): return value
        case .double(let value): return value
        case .date(let value): return value
        case .number(let value): return value
        case .unsupported(let value): return value
        }
    }

    func asString() -> (String, Bool) {
        switch self {
        case .string(let value): return (value, false)
        case .strings(let value): return (Utils.toJson(obj: value), true)
        case .bool(let value): return (value.description, true)
        case .int(let value): return (value.description, true)
        case .int8(let value): return (value.description, true)
        case .int16(let value): return (value.description, true)
        case .int32(let value): return (value.description, true)
        case .int64(let value): return (value.description, true)
        case .uint(let value): return (value.description, true)
        case .uint8(let value): return (value.description, true)
        case .uint16(let value): return (value.description, true)
        case .uint32(let value): return (value.description, true)
        case .uint64(let value): return (value.description, true)
        case .float(let value): return (Self.floatingString(value), true)
        case .double(let value): return (Self.floatingString(value), true)
        case .date(let value): return (value.timeIntervalSince1970.description, true)
        case .number(let value):
            return Self.numericAttribute(value)?.asString() ?? ("\(value)", true)
        case .unsupported(let value): return (value, true)
        }
    }

    func asDouble() -> Double? {
        switch self {
        case .string(let value):
            let stringValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch stringValue {
            case "Infinity", "+Infinity": return .infinity
            case "-Infinity": return -.infinity
            case "NaN": return .nan
            default: return Double(stringValue.replacingOccurrences(of: ",", with: "."))
            }
        case .int(let value): return Double(value)
        case .int8(let value): return Double(value)
        case .int16(let value): return Double(value)
        case .int32(let value): return Double(value)
        case .int64(let value): return Double(value)
        case .uint(let value): return Double(value)
        case .uint8(let value): return Double(value)
        case .uint16(let value): return Double(value)
        case .uint32(let value): return Double(value)
        case .uint64(let value): return Double(value)
        case .float(let value): return Double(value)
        case .double(let value): return value
        case .number(let value): return Self.numericAttribute(value)?.asDouble()
        default: return nil
        }
    }

    func asDateDouble() -> Double? {
        if case .date(let value) = self {
            return value.timeIntervalSince1970
        }
        return asDouble()
    }

    func asSemver() -> Version? {
        if case .string(let value) = self {
            return value.toVersion()
        }
        return nil
    }

    func asSlice() -> [String]? {
        switch self {
        case .strings(let value): return value
        case .string(let value): return Utils.fromJson(json: value)
        default: return nil
        }
    }

    private static func floatingString<T: BinaryFloatingPoint & CustomStringConvertible>(_ value: T) -> String {
        return value.isNaN ? "NaN" : value.isInfinite ? (value < 0 ? "-Infinity" : "Infinity") : value.description
    }

    private static func numericAttribute(_ value: NSNumber) -> UserAttribute? {
        switch value as Any {
        case let value as Int: return .int(value)
        case let value as Int8: return .int8(value)
        case let value as Int16: return .int16(value)
        case let value as Int32: return .int32(value)
        case let value as Int64: return .int64(value)
        case let value as UInt: return .uint(value)
        case let value as UInt8: return .uint8(value)
        case let value as UInt16: return .uint16(value)
        case let value as UInt32: return .uint32(value)
        case let value as UInt64: return .uint64(value)
        case let value as Float: return .float(value)
        case let value as Double: return .double(value)
        default: return nil
        }
    }
}

/// User Object. Contains user attributes which are used for evaluating targeting rules and percentage options.
public final class ConfigCatUser: NSObject, Sendable {
    @objc public static let idKey: String = "Identifier"
    @objc public static let emailKey: String = "Email"
    @objc public static let countryKey: String = "Country"
    
    private let attributes: [String: UserAttribute]
    
    /// The user object's identifier.
    public let identifier: String
    
    /**
     Initializes a new `ConfigCatUser`.
     
     - Parameter identifier: The unique identifier of the user or session (e.g. email address, primary key, session ID, etc.)
     - Parameter email: Optional, email address of the user.
     - Parameter country: Optional, country of the user.
     - Parameter custom: Optional, custom attributes of the user for advanced targeting rule definitions (e.g. role, subscription type, etc.)
     - Returns: A new `ConfigCatUser`.
     
     All comparators support `String` values as User Object attribute (in some cases they need to be provided in a specific format though, see below),
     but some of them also support other types of values. It depends on the comparator how the values will be handled. The following rules apply:
     
     **Text-based comparators** (EQUALS, IS ONE OF, etc.)
     * accept `String` values,
     * all other values are automatically converted to `String` (a warning will be logged but evaluation will continue as normal).
     
     **SemVer-based comparators** (IS ONE OF, &lt;, &gt;=, etc.)
     * accept `String` values containing a properly formatted, valid semver value,
     * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
     
     **Number-based comparators** (=, &lt;, &gt;=, etc.)
     * accept `Int`, `UInt`, `Double`, or `Float` values,
     * accept `String` values containing a properly formatted, valid `Double` value,
     * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
     
     **Date time-based comparators** (BEFORE / AFTER)
     * accept `Date` values, which are automatically converted to a second-based Unix timestamp,
     * accept `Int`, `UInt`, `Double`, or `Float` values representing a second-based Unix timestamp,
     * accept `String` values containing a properly formatted, valid `Double` value,
     * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
     
     **String array-based comparators** (ARRAY CONTAINS ANY OF / ARRAY NOT CONTAINS ANY OF)
     * accept arrays of `String`,
     * accept `String` values containing a valid JSON string which can be deserialized to an array of `String`,
     * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).

     Unsupported attribute values are stored as a snapshot of their string representation.
     They remain invalid for non-text comparators.
     */
    @objc public init(identifier: String,
                      email: String? = nil,
                      country: String? = nil,
                      custom: [String: Any]? = nil) {
        
        var attributes: [String: UserAttribute] = [:]
        self.identifier = identifier
        attributes[ConfigCatUser.idKey] = .string(identifier)
        
        if let email = email {
            attributes[ConfigCatUser.emailKey] = .string(email)
        }
        
        if let country = country {
            attributes[ConfigCatUser.countryKey] = .string(country)
        }
        
        if let custom = custom {
            for (key, value) in custom {
                if !ConfigCatUser.isPredefinedKey(key: key) {
                    attributes[key] = UserAttribute(value)
                }
            }
        }
        self.attributes = attributes
    }
    
    init(custom: [String: Any]) {
        self.attributes = custom.mapValues { UserAttribute($0) }
        self.identifier = custom[ConfigCatUser.idKey] as? String ?? ""
    }
    
    /**
     Returns the user attribute value identified by the given key.
     
     - Parameter key: The key of the user attribute.
     - Returns: The user attribute value, or a string snapshot for an unsupported value.
     */
    @objc public func attribute(for key: String) -> Any? {
        return attributeValue(for: key)?.anyValue
    }

    func attributeValue(for key: String) -> UserAttribute? {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        return attributes[key]
    }
    
    static func isPredefinedKey(key: String) -> Bool {
        return key == ConfigCatUser.idKey || key == ConfigCatUser.emailKey || key == ConfigCatUser.countryKey
    }
    
    public override var description: String {
        var map = [String: Any]()
        for (key, attribute) in attributes {
            let value = attribute.anyValue
            switch value {
            case is String, is [String], is Int, is Int8, is Int16, is Int32, is Int64, is UInt, is UInt8, is UInt16, is UInt32, is UInt64, is Float, is Float32, is Float64, is Double:
                map[key] = value
            default:
                map[key] = "\(value)"
            }
        }
        return Utils.toJson(obj: map)
    }
}
