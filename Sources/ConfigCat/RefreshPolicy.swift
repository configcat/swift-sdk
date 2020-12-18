import os.log
import Foundation

/// The public interface of a refresh policy which's implementors should describe the configuration update rules.
class RefreshPolicy : NSObject {
    let cache: ConfigCache
    let fetcher: ConfigFetcher
    let log: Logger
    
    fileprivate var inMemoryValue: String = ""
    fileprivate let cacheKey: String
    
    final func writeCache(value: String) {
        self.inMemoryValue = value
        do {
            try self.cache.write(for: self.cacheKey, value: value)
        } catch {
            self.log.error(message: "An error occured during the cache write: %@", error.localizedDescription)
        }
    }
    
    final func readCache() -> String {
        do {
            return try self.cache.read(for: self.cacheKey)
        } catch {
            self.log.error(message: "An error occured during the cache read, using in memory value: %@", error.localizedDescription)
            return self.inMemoryValue
        }
    }
    
    var lastCachedConfiguration: String {
        return self.inMemoryValue
    }
    
    /**
     Initializes a new `RefreshPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `RefreshPolicy`.
     */
    public required init(cache: ConfigCache, fetcher: ConfigFetcher, logger: Logger, sdkKey: String) {
        self.cache = cache
        self.fetcher = fetcher
        self.log = logger
        let keyToHash = "swift_" + sdkKey + "_" + ConfigFetcher.configJsonName
        self.cacheKey = String(keyToHash.sha1hex ?? keyToHash)
    }
    
    /**
     Child classes has to implement this method, the `ConfigCatClient` uses it
     to read the current configuration value through the applied policy.
     
     - Returns: the AsyncResult object which computes the configuration.
     */
    open func getConfiguration() -> AsyncResult<String> {
        assert(false, "Method must be overidden!")
        return AsyncResult(result: "")
    }
    
    /**
     Initiates a force refresh on the cached configuration.
     
     - Returns: the Async object which executes the refresh.
     */
    public final func refresh() -> Async {
        return self.fetcher.getConfigurationJson().accept { response in
            if response.isFetched() {
                self.writeCache(value: response.body)
            }
        }
    }
}
