import Foundation

/// Describes a `RefreshPolicy` which fetches the latest configuration over HTTP every time when a get is called on the `ConfigCatClient`.
final class ManualPollingPolicy : RefreshPolicy {
    /**
     Initializes a new `ManualPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.
     - Returns: A new `ManualPollingPolicy`.
     */
    public required init(cache: ConfigCache,
                         fetcher: ConfigFetcher,
                         logger: Logger,
                         sdkKey: String) {
        super.init(cache: cache, fetcher: fetcher, logger: logger, sdkKey: sdkKey)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        return AsyncResult<String>.completed(result: self.readCache())
    }
}
