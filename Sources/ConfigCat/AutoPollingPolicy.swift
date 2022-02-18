import Foundation
import os.log

/// Describes a `RefreshPolicy` which polls the latest configuration over HTTP and updates the local cache repeatedly.
final class AutoPollingPolicy : RefreshPolicy {
    fileprivate let autoPollIntervalInSeconds: Double
    fileprivate let initialized = Synced<Bool>(initValue: false)
    fileprivate var initResult = Async()
    fileprivate let timer = DispatchSource.makeTimerSource()
    fileprivate let initTimer = DispatchSource.makeTimerSource()
    fileprivate let onConfigChanged: ConfigCatClient.ConfigChangedHandler?
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.          
     - Returns: A new `AutoPollingPolicy`.
     */
    public convenience required init(cache: ConfigCache?, fetcher: ConfigFetcher, logger: Logger, configJsonCache: ConfigJsonCache, sdkKey: String) {
        self.init(cache: cache, fetcher: fetcher, logger: logger, configJsonCache: configJsonCache, sdkKey: sdkKey, config: AutoPollingMode())
    }
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter sdkKey: the sdk key.
     - Parameter config: the configuration.
     - Returns: A new `AutoPollingPolicy`.
     */
    public init(cache: ConfigCache?,
                fetcher: ConfigFetcher,
                logger: Logger,
                configJsonCache: ConfigJsonCache,
                sdkKey: String,
                config: AutoPollingMode) {
        self.autoPollIntervalInSeconds = config.autoPollIntervalInSeconds
        self.onConfigChanged = config.onConfigChanged
        super.init(cache: cache, fetcher: fetcher, logger: logger, configJsonCache: configJsonCache, sdkKey: sdkKey)
        
        timer.schedule(deadline: DispatchTime.now(), repeating: autoPollIntervalInSeconds)
        timer.setEventHandler(handler: { [weak self] in
            guard let `self` = self else {
                return
            }

            if self.fetcher.isFetching() {
                self.log.debug(message: "Config fetching is skipped because there is an ongoing fetch request")
                return;
            }

            self.fetcher.getConfiguration()
                .apply(completion: { response in
                    let cached = self.readConfigCache()
                    if let config = response.config, response.isFetched() && config.jsonString != cached.jsonString {
                        self.writeConfigCache(value: config)
                        self.onConfigChanged?()
                    }
                    
                    if !self.initialized.getAndSet(new: true) {
                        self.initResult.complete()
                    }
                })
        })
        timer.resume()

        // Waiting for the client initialization.
        // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while the config is not ready
        // the default value will be returned.
        initTimer.schedule(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(config.maxInitWaitTimeInSeconds))
        initTimer.setEventHandler(handler: { [weak self] in
            guard let `self` = self else {return}
            if !self.initialized.getAndSet(new: true) {
                self.initResult.complete()
            }
        })
        initTimer.resume()
    }
    
    /// Deinitalizes the AutoPollingPolicy instance.
    deinit {
        self.timer.cancel()
        self.initTimer.cancel()
    }
    
    public override func getConfiguration() -> AsyncResult<Config> {
        if self.initResult.completed {
            return self.readCacheAsync()
        }
        
        return self.initResult.apply(completion: {
            return self.readConfigCache()
        })
    }
    
    private func readCacheAsync() -> AsyncResult<Config> {
        return AsyncResult<Config>.completed(result: self.readConfigCache())
    }
}
