import Foundation

/// User Object. Contains user attributes which are used for evaluating targeting rules and percentage options.
public final class ConfigCatUser: NSObject {
    static let idKey: String = "Identifier"
    static let emailKey: String = "Email"
    static let countryKey: String = "Country"
    
    private var attributes: [String: Any]
    private(set) var identifier: String
    
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
     */
    @objc public init(identifier: String,
                      email: String? = nil,
                      country: String? = nil,
                      custom: [String: Any]? = nil) {
        
        attributes = [:]
        self.identifier = identifier
        attributes[ConfigCatUser.idKey] = identifier
        
        if let email = email {
            attributes[ConfigCatUser.emailKey] = email
        }
        
        if let country = country {
            attributes[ConfigCatUser.countryKey] = country
        }
        
        if let custom = custom {
            for (key, value) in custom {
                if !ConfigCatUser.isPredefinedKey(key: key) {
                    attributes[key] = value
                }
            }
        }
    }
    
    init(custom: [String: Any]) {
        self.attributes = custom
        self.identifier = custom[ConfigCatUser.idKey] as? String ?? ""
    }
    
    func attribute(for key: String) -> Any? {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        guard let value = attributes[key] else {
            return nil
        }
        return value
    }
    
    static func isPredefinedKey(key: String) -> Bool {
        return key == ConfigCatUser.idKey || key == ConfigCatUser.emailKey || key == ConfigCatUser.countryKey
    }
    
    public override var description: String {
        var map = [String: Any]()
        for (key, value) in attributes {
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
