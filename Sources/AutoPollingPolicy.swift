import Foundation
import os.log

/// Describes a `RefreshPolicy` which polls the latest configuration over HTTP and updates the local cache repeatedly.
final class AutoPollingPolicy : RefreshPolicy {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: AutoPollingPolicy.self).bundleIdentifier!, category: "Auto Polling Policy")
    fileprivate static let parser = ConfigParser()
    fileprivate let autoPollIntervalInSeconds: Double
    fileprivate let initialized = Synced<Bool>(initValue: false)
    fileprivate var initResult = Async()
    fileprivate let timer = DispatchSource.makeTimerSource()
    fileprivate let onConfigChanged: ConfigCatClient.ConfigChangedHandler?
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Returns: A new `AutoPollingPolicy`.
     */
    public convenience required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        self.init(cache: cache, fetcher: fetcher, config: AutoPollingMode())
    }
    
    /**
     Initializes a new `AutoPollingPolicy`.
     
     - Parameter cache: the internal cache instance.
     - Parameter fetcher: the internal config fetcher instance.
     - Parameter config: the configuration.
     - Returns: A new `AutoPollingPolicy`.
     */
    public init(cache: ConfigCache,
                fetcher: ConfigFetcher,
                config: AutoPollingMode) {
        self.autoPollIntervalInSeconds = config.autoPollIntervalInSeconds
        self.onConfigChanged = config.onConfigChanged
        super.init(cache: cache, fetcher: fetcher)
        
        timer.schedule(deadline: DispatchTime.now(), repeating: autoPollIntervalInSeconds)
        timer.setEventHandler(handler: { [weak self] in
            guard let `self` = self else {
                return
            }
            
            os_log("Polling the latest configuration", log: AutoPollingPolicy.log, type: .debug)
            self.fetcher.getConfigurationJson()
                .apply(completion: { response in
                    let cached = self.cache.get()
                    if response.isFetched() && response.body != cached {
                        self.cache.set(value: response.body)
                        self.onConfigChanged?(response.body, AutoPollingPolicy.parser)
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
            return self.readCache()
        }
        
        return self.initResult.apply(completion: {
            return self.cache.get()
        })
    }
    
    private func readCache() -> AsyncResult<String> {
        os_log("Reading from cache", log: AutoPollingPolicy.log, type: .debug)
        return AsyncResult<String>.completed(result: self.cache.get())
    }
}
