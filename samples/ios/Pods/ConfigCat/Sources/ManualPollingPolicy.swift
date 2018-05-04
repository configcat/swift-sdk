import Foundation

/// Describes a `RefreshPolicy` which fetches the latest configuration over HTTP every time when a get is called on the `ConfigCatClient`.
public final class ManualPollingPolicy : RefreshPolicy {
    /**
     Initializes a new `ManualPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `ManualPollingPolicy`.
     */
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        fetcher.mode = "manual"
        super.init(cache: cache, fetcher: fetcher)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        return super.fetcher.getConfigurationJson()
            .apply(completion: { response in
                let cached = super.cache.get()
                let config = response.body
                if response.isFetched() && config != cached {
                    super.cache.set(value: config)
                }
                
                return response.isFetched() ? config : cached
            })
    }
}
