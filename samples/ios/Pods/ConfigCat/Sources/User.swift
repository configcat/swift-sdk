import Foundation

/// An object containing attributes to properly identify a given user for rollout evaluation.
public final class User {
    fileprivate var attributes: [String: String]
    fileprivate(set) var identifier: String
    
    public init(identifier: String,
                email: String? = nil,
                country: String? = nil,
                custom: [String: String]? = nil) {
        
        if identifier.isEmpty {
            assert(false, "identifier cannot be empty")
        }
        
        attributes = [:]
        self.identifier = identifier
        attributes["identifier"] = identifier
        
        if let email = email {
            attributes["email"] = email
        }
        
        if let country = country {
            attributes["country"] = country
        }
        
        if let custom = custom {
            for (key, value) in custom {
                attributes[key.lowercased()] = value
            }
        }
    }
    
    func getAttribute(for key: String) -> String? {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        
        if let value = self.attributes[key.lowercased()] {
            return value
        }
        
        return nil
    }
}
