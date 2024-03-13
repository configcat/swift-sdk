import Foundation

/// User Object. Contains user attributes which are used for evaluating targeting rules and percentage options.
public final class ConfigCatUser: NSObject {
    private var attributes: [String: Any]
    private(set) var identifier: String

    /**
     Initializes a new `ConfigCatUser`.
     
     - Parameter identifier: The unique identifier of the user or session (e.g. email address, primary key, session ID, etc.)
     - Parameter email: Optional, email address of the user.
     - Parameter country: Optional, country of the user.
     - Parameter custom: Optional, custom attributes of the user for advanced targeting rule definitions (e.g. role, subscription type, etc.)
     - Returns: A new `ConfigCatUser`.
     
     All comparators support `string` values as User Object attribute (in some cases they need to be provided in a specific format though, see below),
     but some of them also support other types of values. It depends on the comparator how the values will be handled. The following rules apply:
     
     **Text-based comparators** (EQUALS, IS ONE OF, etc.)
      * accept `string` values,
      * all other values are automatically converted to `string` (a warning will be logged but evaluation will continue as normal).
    
     **SemVer-based comparators** (IS ONE OF, &lt;, &gt;=, etc.)
      * accept `string` values containing a properly formatted, valid semver value,
      * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
    
     **Number-based comparators** (=, &lt;, &gt;=, etc.)
      * accept `int` or `float` values,
      * accept `string` values containing a properly formatted, valid `int` or `float` value,
      * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
    
     **Date time-based comparators** (BEFORE / AFTER)
      * accept `DateTimeInterface` values, which are automatically converted to a second-based Unix timestamp,
      * accept `int` or `float` values representing a second-based Unix timestamp,
      * accept `string` values containing a properly formatted, valid `int` or `float` value,
      * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
    
     **String array-based comparators** (ARRAY CONTAINS ANY OF / ARRAY NOT CONTAINS ANY OF)
      * accept arrays of `string`,
      * accept `string` values containing a valid JSON string which can be deserialized to an array of `string`,
      * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
     */
    @objc public init(identifier: String,
                      email: String? = nil,
                      country: String? = nil,
                      custom: [String: Any]? = nil) {

        attributes = [:]
        self.identifier = identifier
        attributes["Identifier"] = identifier

        if let email = email {
            attributes["Email"] = email
        }

        if let country = country {
            attributes["Country"] = country
        }

        if let custom = custom {
            for (key, value) in custom {
                attributes[key] = value
            }
        }
    }
    
    init(custom: [String: Any]) {
        self.attributes = custom
        self.identifier = custom["Identifier"] as? String ?? ""
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
    
    public override var description: String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: attributes, options: [])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
