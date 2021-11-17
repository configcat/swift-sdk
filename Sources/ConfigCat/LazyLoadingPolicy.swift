import Foundation
import Dispatch
import os.log

/// Describes a `RefreshPolicy` which uses an expiring cache to maintain the internally stored configuration.
final class LazyLoadingPolicy : RefreshPolicy {
    fileprivate let cacheRefreshIntervalInSeconds: Double
    fileprivate let useAsyncRefresh: Bool
    fileprivate var lastRefreshTime = Date.distantPast
    fileprivate let initialized = Synced<Bool>(initValue: false)
    fileprivate let isFetching = Synced<Bool>(initValue: false)
    fileprivate var fetching = AsyncResult<String>()
    fileprivate let initAsync = Async()
    
    /**
     Initializes a new `LazyLoadingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.
     - Returns: A new `LazyLoadingPolicy`.
     */
    public convenience required init(cache: ConfigCache, fetcher: ConfigFetcher, logger: Logger, sdkKey: String) {
        self.init(cache: cache, fetcher: fetcher, logger: logger, sdkKey: sdkKey, config: LazyLoadingMode())
    }
    
    /**
     Initializes a new `LazyLoadingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.
     - Parameter config: the configuration.
     - Returns: A new `LazyLoadingPolicy`.
     */
    public init(cache: ConfigCache,
                fetcher: ConfigFetcher,
                logger: Logger,
                sdkKey: String,
                config: LazyLoadingMode) {
        self.cacheRefreshIntervalInSeconds = config.cacheRefreshIntervalInSeconds
        self.useAsyncRefresh = config.useAsyncRefresh
        super.init(cache: cache, fetcher: fetcher, logger: logger, sdkKey: sdkKey)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        if self.lastRefreshTime.timeIntervalSinceNow < -self.cacheRefreshIntervalInSeconds {
            let initialized = self.initAsync.completed
            if initialized && !self.isFetching.testAndSet(expect: false, new: true) {
                return self.useAsyncRefresh
                    ? self.readCacheAsync()
                    : self.fetching
            }
            
            if initialized {
                self.fetching = self.fetch()
                if self.useAsyncRefresh {
                    return self.readCacheAsync()
                }
                return self.fetching
            } else {
                if self.isFetching.testAndSet(expect: false, new: true) {
                    self.fetching = self.fetch()
                }
                return self.initAsync.apply(completion: {
                    return super.readCache()
                })
            }
        }
        
        return self.readCacheAsync()
    }
    
    private func fetch() -> AsyncResult<String> {
        return self.fetcher.getConfigurationJson()
            .apply(completion: { response in
                let cached = super.readCache()
                if response.isFetched() && response.body != cached {
                    super.writeCache(value: response.body)
                }
                
                if !response.isFailed() {
                    self.lastRefreshTime = Date()
                }
                
                if(self.initialized.testAndSet(expect: false, new: true)) {
                    self.initAsync.complete()
                }
                
                self.isFetching.set(new: false)
                
                return response.isFetched()
                    ? response.body
                    : cached
            })
    }
    
    private func readCacheAsync() -> AsyncResult<String> {
        return AsyncResult<String>.completed(result: self.readCache())
    }
}
