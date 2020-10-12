import Foundation

/// A cache API used to make custom cache implementations for `ConfigCatClient`.
@objc public protocol ConfigCache {
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

/// An in-memory cache implementation used to store the fetched configurations.
internal final class InMemoryConfigCache : NSObject, ConfigCache {
    private var store = [String: String]()
    
    public func read(for key: String) throws -> String {
        return self.store[key] ?? ""
    }
    
    public func write(for key: String, value: String) throws {
        self.store[key] = value
    }
}
