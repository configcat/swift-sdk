/// The public interface of a refresh policy which's implementors should describe the configuration update rules.
open class RefreshPolicy {
    public let cache: ConfigCache
    public let fetcher: ConfigFetcher
    
    var lastCachedConfiguration: String {
        return self.cache.inMemoryValue
    }
    
    /**
     Initializes a new `RefreshPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `RefreshPolicy`.
     */
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        self.cache = cache
        self.fetcher = fetcher
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
                self.cache.set(value: response.body)
            }
        }
    }
}
