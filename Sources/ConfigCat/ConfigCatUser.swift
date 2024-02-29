import Foundation

/// An object containing attributes to properly identify a given user for rollout evaluation.
public final class ConfigCatUser: NSObject {
    private var attributes: [String: Any]
    private(set) var identifier: String

    /**
     Initializes a new `User`.
     
     - Parameter identifier: the SDK Key for to communicate with the ConfigCat services.
     - Parameter email: optional, sets the email of the user.
     - Parameter country: optional, sets the country of the user.
     - Parameter custom: optional, sets the custom attributes of a user.
     - Returns: A new `User`.
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
