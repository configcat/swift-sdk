import os.log
import Foundation

/// The public interface of a refresh policy which's implementors should describe the configuration update rules.
class RefreshPolicy : NSObject {
    let cache: ConfigCache?
    let fetcher: ConfigFetcher
    let log: Logger
    
    fileprivate let configJsonCache: ConfigJsonCache
    fileprivate let cacheKey: String
    
    final func writeConfigCache(value: Config) {
        self.configJsonCache.config = value
        if let cache = self.cache {
            do {
                try cache.write(for: self.cacheKey, value: value.jsonString)
            } catch {
                self.log.error(message: "An error occurred during the cache write: %@", error.localizedDescription)
            }
        }
    }
    
    final func readConfigCache() -> Config {
        guard let cache = self.cache else {
            return self.configJsonCache.config
        }

        do {
            return try self.configJsonCache.getConfigFromJson(json: cache.read(for: self.cacheKey))
        } catch {
            self.log.error(message: "An error occurred during the cache read, using in memory value: %@", error.localizedDescription)
            return self.configJsonCache.config
        }
    }

    /**
     Initializes a new `RefreshPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `RefreshPolicy`.
     */
    required init(cache: ConfigCache?, fetcher: ConfigFetcher, logger: Logger, configJsonCache: ConfigJsonCache, sdkKey: String) {
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
    func getConfiguration() -> AsyncResult<Config> {
        assert(false, "Method must be overridden!")
        return AsyncResult(result: .empty)
    }

    func getSettings() -> AsyncResult<[String: Any]> {
        self.getConfiguration()
                .apply(completion: { config in
                    return config.entries
                })
    }
    
    /**
     Initiates a force refresh on the cached configuration.
     
     - Returns: the Async object which executes the refresh.
     */
    final func refresh() -> Async {
        return self.fetcher.getConfiguration().accept { response in
            if let config = response.config, response.isFetched() {
                self.writeConfigCache(value: config)
            }
        }
    }
}
