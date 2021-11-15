import Foundation
import os.log

/// Describes a `RefreshPolicy` which polls the latest configuration over HTTP and updates the local cache repeatedly.
final class AutoPollingPolicy : RefreshPolicy {
    fileprivate let autoPollIntervalInSeconds: Double
    fileprivate let initialized = Synced<Bool>(initValue: false)
    fileprivate var initResult = Async()
    fileprivate let timer = DispatchSource.makeTimerSource()
    fileprivate let onConfigChanged: ConfigCatClient.ConfigChangedHandler?
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.          
     - Returns: A new `AutoPollingPolicy`.
     */
    public convenience required init(cache: ConfigCache, fetcher: ConfigFetcher, logger: Logger, sdkKey: String) {
        self.init(cache: cache, fetcher: fetcher, logger: logger, sdkKey: sdkKey, config: AutoPollingMode())
    }
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.
     - Parameter config: the configuration.
     - Returns: A new `AutoPollingPolicy`.
     */
    public init(cache: ConfigCache,
                fetcher: ConfigFetcher,
                logger: Logger,
                sdkKey: String,
                config: AutoPollingMode) {
        self.autoPollIntervalInSeconds = config.autoPollIntervalInSeconds
        self.onConfigChanged = config.onConfigChanged
        super.init(cache: cache, fetcher: fetcher, logger: logger, sdkKey: sdkKey)
        
        timer.schedule(deadline: DispatchTime.now(), repeating: autoPollIntervalInSeconds)
        timer.setEventHandler(handler: { [weak self] in
            guard let `self` = self else {
                return
            }

            if self.fetcher.isFetchingConfigurationJson() {
                self.log.debug(message: "Config fetching is skipped because there is an ongoing fetch request")
                return;
            }

            self.fetcher.getConfigurationJson()
                .apply(completion: { response in
                    let cached = self.readCache()
                    if response.isFetched() && response.body != cached {
                        self.writeCache(value: response.body)
                        self.onConfigChanged?()
                    }
                    
                    if !self.initialized.getAndSet(new: true) {
                        self.initResult.complete()
                    }
                })
        })
        timer.resume()
    }
    
    /// Deinitalizes the AutoPollingPolicy instance.
    deinit {
        self.timer.cancel()
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        if self.initResult.completed {
            return self.readCacheAsync()
        }
        
        return self.initResult.apply(completion: {
            return self.readCache()
        })
    }
    
    private func readCacheAsync() -> AsyncResult<String> {
        return AsyncResult<String>.completed(result: self.readCache())
    }
}
