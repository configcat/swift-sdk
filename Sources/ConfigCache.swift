import os.log
import Foundation

open class ConfigCache {
    var inMemoryValue: String = ""
    let log: OSLog = OSLog(subsystem: Bundle(for: ConfigCache.self).bundleIdentifier!, category: "Config Cache")
    
    public init() { }
    
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
    
    open func read() throws -> String {
        assert(false, "read() method must be overidden")
        return ""
    }
    
    open func write(value: String) throws {
        assert(false, "write() method must be overidden")
    }
}

public final class InMemoryConfigCache : ConfigCache {
    open override func read() throws -> String {
        return super.inMemoryValue
    }
    
    open override func write(value: String) throws {
        // no action
    }
}
