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
    public class func autoPoll(autoPollIntervalInSeconds: Int = 60, maxInitWaitTimeInSeconds: Int = 5, onConfigChanged: ConfigCatClient.ConfigChangedHandler? = nil) -> PollingMode {
        AutoPollingMode(autoPollIntervalInSeconds: autoPollIntervalInSeconds, maxInitWaitTimeInSeconds: maxInitWaitTimeInSeconds, onConfigChanged: onConfigChanged)
    }
    /**
    Creates a new `LazyLoadingMode`.
    
    - Parameter cacheRefreshIntervalInSeconds: sets how long the cache will store its value before fetching the latest from the network again.
    - Returns: A new `LazyLoadingMode`.
    */
    public class func lazyLoad(cacheRefreshIntervalInSeconds: Int = 60) -> PollingMode {
        LazyLoadingMode(cacheRefreshIntervalInSeconds: cacheRefreshIntervalInSeconds)
    }
    /**
    Creates a new `ManualPollingMode`.
    
    - Returns: A new `ManualPollingMode`.
    */
    public class func manualPoll() -> PollingMode {
        ManualPollingMode()
    }
}
