import Foundation
import Dispatch
import os.log

/// Describes a `RefreshPolicy` which uses an expiring cache to maintain the internally stored configuration.
public final class ExpiringCachePolicy : RefreshPolicy {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ExpiringCachePolicy.self).bundleIdentifier!, category: "Expiring Cache Policy")
    fileprivate let cacheRefreshIntervalInSeconds: Double
    fileprivate let useAsyncRefresh: Bool
    fileprivate var lastRefreshTime = Date.distantPast
    fileprivate let initialized = Synced<Bool>(initValue: false)
    fileprivate let isFetching = Synced<Bool>(initValue: false)
    fileprivate var fetching = AsyncResult<String>()
    
    /**
     Initializes a new `ExpiringCachePolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `ExpiringCachePolicy`.
     */
    public convenience required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        self.init(cache: cache, fetcher: fetcher, cacheRefreshIntervalInSeconds: 120, useAsyncRefresh: true)
    }
    
    /**
     Initializes a new `ExpiringCachePolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter cacheRefreshIntervalInSeconds: sets how long the cache will store its value before fetching the latest from the network again.
     - Parameter useAsyncRefresh: sets whether the cache should refresh itself asynchronously or synchronously. If it's set to `true` reading from the policy will not wait for the refresh to be finished, instead it returns immediately with the previous stored value. If it's set to `false` the policy will wait until the expired value is being refreshed with the latest configuration.
     - Returns: A new `ExpiringCachePolicy`.
     */
    public init(cache: ConfigCache, fetcher: ConfigFetcher, cacheRefreshIntervalInSeconds: Double, useAsyncRefresh: Bool) {
        self.cacheRefreshIntervalInSeconds = cacheRefreshIntervalInSeconds
        self.useAsyncRefresh = useAsyncRefresh
        fetcher.mode = "ecache"
        super.init(cache: cache, fetcher: fetcher)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        if self.lastRefreshTime.timeIntervalSinceNow < -self.cacheRefreshIntervalInSeconds {
            if !self.isFetching.testAndSet(expect: false, new: true) {
                return self.useAsyncRefresh
                    ? self.readCache()
                    : self.fetching
            }
            
            os_log("Cache expired, refreshing", log: ExpiringCachePolicy.log, type: .debug)
            self.fetching = self.fetcher.getConfigurationJson()
                .apply(completion: { response in
                    let cached = super.cache.get()
                    if response.isFetched() && response.body != cached {
                        super.cache.set(value: response.body)
                        self.isFetching.set(new: false)
                        self.initialized.set(new: true)
                    }
                    
                    if !response.isFailed() {
                        self.lastRefreshTime = Date()
                    }
                    
                    return response.isFetched()
                        ? response.body
                        : cached
                })
            
            return self.useAsyncRefresh && self.initialized.get()
                ? self.readCache()
                : self.fetching;
        }
        
        return self.readCache()
    }
    
    private func readCache() -> AsyncResult<String> {
        os_log("Reading from cache", log: ExpiringCachePolicy.log, type: .debug)
        return AsyncResult<String>.completed(result: self.cache.get())
    }
}
