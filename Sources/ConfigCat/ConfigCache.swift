import Foundation

/// A cache API used to make custom cache implementations for `ConfigCatClient`.
/// Methods may be called concurrently; custom implementations must synchronize their state.
@objc public protocol ConfigCache: Sendable {
    /**
     Child classes has to implement this method, the `ConfigCatClient`
     uses it to get the actual value from the cache.
     
     - Parameter key: the key of the value.
     - Returns: the cached configuration.
     - Throws: Exception if unable to read the cache.
     */
    func read(for key: String) throws -> String

    /**
     Child classes has to implement this method, the `ConfigCatClient`
     uses it to set the actual cached value.
     
     - Parameter key: the key of the value.
     - Parameter value: the new value to cache.
     - Throws: Exception if unable to save the value.
     */
    func write(for key: String, value: String) throws
}

final class UserDefaultsCache: ConfigCache {
    private let prefix = "com.configcat-"

    func read(for key: String) throws -> String {
        UserDefaults.standard.string(forKey: prefix + key) ?? ""
    }

    func write(for key: String, value: String) throws {
        UserDefaults.standard.set(value, forKey: prefix + key)
    }
}
