import os.log
import Foundation

/// The public interface of a refresh policy which's implementors should describe the configuration update rules.
class RefreshPolicy : NSObject {
    let cache: ConfigCache
    let fetcher: ConfigFetcher
    let log: Logger
    
    fileprivate let configJsonCache: ConfigJsonCache
    fileprivate var inMemoryConfig: Config = Config()
    fileprivate let cacheKey: String
    
    final func writeConfigCache(value: Config) {
        do {
            self.inMemoryConfig = value
            try self.cache.write(for: self.cacheKey, value: value.jsonString)
        } catch {
            self.log.error(message: "An error occurred during the cache write: %@", error.localizedDescription)
        }
    }
    
    final func readConfigCache() -> Config {
        do {
            let config = try self.configJsonCache.getConfigFromJson(json: self.cache.read(for: self.cacheKey))
            return config ?? inMemoryConfig
        } catch {
            self.log.error(message: "An error occurred during the cache read, using in memory value: %@", error.localizedDescription)
            return inMemoryConfig
        }
    }

    /**
     Initializes a new `RefreshPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `RefreshPolicy`.
     */
    public required init(cache: ConfigCache, fetcher: ConfigFetcher, logger: Logger, configJsonCache: ConfigJsonCache, sdkKey: String) {
        self.cache = cache
        self.fetcher = fetcher
        self.log = logger
        self.configJsonCache = configJsonCache
        let keyToHash = "swift_" + sdkKey + "_" + ConfigFetcher.configJsonName
        self.cacheKey = String(keyToHash.sha1hex ?? keyToHash)
    }
    
    /**
     Child classes has to implement this method, the `ConfigCatClient` uses it
     to read the current configuration value through the applied policy.
     
     - Returns: the AsyncResult object which computes the configuration.
     */
    open func getConfiguration() -> AsyncResult<Config> {
        assert(false, "Method must be overridden!")
        return AsyncResult(result: Config())
    }

    open func getSettings() -> AsyncResult<[String: Any]> {
        self.getConfiguration()
                .apply(completion: { config in
                    return config.entries
                })
    }
    
    /**
     Initiates a force refresh on the cached configuration.
     
     - Returns: the Async object which executes the refresh.
     */
    public final func refresh() -> Async {
        return self.fetcher.getConfiguration().accept { response in
            if let config = response.config, response.isFetched() {
                self.writeConfigCache(value: config)
            }
        }
    }
}
