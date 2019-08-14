import os.log
import Foundation

/// A cache API used to make custom cache implementations for `ConfigCatClient`.
open class ConfigCache : NSObject {
    /**
     Through this getter, the in-memory representation of the cached value can be accessed.
     When the underlying cache implementations is not able to load or store its value,
     this will represent the latest cached configuration.
     
     - Returns: the cached value in memory.
     */
    var inMemoryValue: String = ""
    
    let log: OSLog = OSLog(subsystem: Bundle(for: ConfigCache.self).bundleIdentifier!, category: "Config Cache")
    
    public override init() { }
    
    public final func set(value: String) {
        self.inMemoryValue = value
        do {
           try self.write(value: value)
        } catch {
            os_log("An error occured during the cache write: %@", log: self.log, type: .error, error.localizedDescription)
        }
    }
    
    public final func get() -> String {
        do {
            return try self.read()
        } catch {
            os_log("An error occured during the cache read, using in memory value: %@", log: self.log, type: .error, error.localizedDescription)
            return self.inMemoryValue
        }
    }
    
    /**
     Child classes has to implement this method, the `ConfigCatClient`
     uses it to get the actual value from the cache.
     
     - Returns: the cached configuration.
     - Throws: Exception if unable to read the cache.
     */
    open func read() throws -> String {
        assert(false, "read() method must be overidden")
        return ""
    }
    
    /**
     Child classes has to implement this method, the `ConfigCatClient`
     uses it to set the actual cached value.
     
     - Parameter value: the new value to cache.
     - Throws: Exception if unable to save the value.
     */
    open func write(value: String) throws {
        assert(false, "write() method must be overidden")
    }
}

/// An in-memory cache implementation used to store the fetched configurations.
public final class InMemoryConfigCache : ConfigCache {
    public override func read() throws -> String {
        return super.inMemoryValue
    }
    
    public override func write(value: String) throws {
        // no action
    }
}
