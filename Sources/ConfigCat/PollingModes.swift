import Foundation

/// Describes the polling modes.
public final class PollingModes {
    /**
    Creates a new `AutoPollingMode`.
    
    - Parameter autoPollIntervalInSeconds: the poll interval in seconds.
    - Parameter maxInitWaitTimeInSeconds: maximum waiting time between initialization and the first config acquisition in seconds.
    - Parameter onConfigChanged: the configuration changed event handler.
    - Returns: A new `AutoPollingMode`.
    */
    public class func autoPoll(autoPollIntervalInSeconds: Double, maxInitWaitTimeInSeconds: Int = 5, onConfigChanged: ConfigCatClient.ConfigChangedHandler? = nil) -> PollingMode {
        return AutoPollingMode(autoPollIntervalInSeconds: autoPollIntervalInSeconds, maxInitWaitTimeInSeconds: maxInitWaitTimeInSeconds, onConfigChanged: onConfigChanged)
    }
    /**
    Creates a new `LazyLoadingMode`.
    
    - Parameter cacheRefreshIntervalInSeconds: sets how long the cache will store its value before fetching the latest from the network again.
    - Parameter useAsyncRefresh: sets whether the cache should refresh itself asynchronously or synchronously. If it's set to `true` reading from the policy will not wait for the refresh to be finished, instead it returns immediately with the previous stored value. If it's set to `false` the policy will wait until the expired value is being refreshed with the latest configuration.
    - Returns: A new `LazyLoadingMode`.
    */
    public class func lazyLoad(cacheRefreshIntervalInSeconds: Double, useAsyncRefresh: Bool = false) -> PollingMode {
        return LazyLoadingMode(cacheRefreshIntervalInSeconds: cacheRefreshIntervalInSeconds, useAsyncRefresh: useAsyncRefresh)
    }
    /**
    Creates a new `ManualPollingMode`.
    
    - Returns: A new `ManualPollingMode`.
    */
    public class func manualPoll() -> PollingMode {
        return ManualPollingMode()
    }
}
