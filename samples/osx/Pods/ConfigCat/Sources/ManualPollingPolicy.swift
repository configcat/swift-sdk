import Foundation

/// Describes a `RefreshPolicy` which fetches the latest configuration over HTTP every time when a get is called on the `ConfigCatClient`.
final class ManualPollingPolicy : RefreshPolicy {
    /**
     Initializes a new `ManualPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `ManualPollingPolicy`.
     */
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        super.init(cache: cache, fetcher: fetcher)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        return AsyncResult<String>.completed(result: self.cache.get())
    }
}
