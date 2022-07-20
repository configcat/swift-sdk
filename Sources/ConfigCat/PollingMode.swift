import Foundation

/// Describes a polling mode.
@objc public protocol PollingMode {
    var identifier: String {get}
}

class AutoPollingMode : PollingMode {
    let autoPollIntervalInSeconds: Int
    let maxInitWaitTimeInSeconds: Int
    let onConfigChanged: ConfigCatClient.ConfigChangedHandler?

    init(autoPollIntervalInSeconds: Int = 60, maxInitWaitTimeInSeconds: Int = 5, onConfigChanged: ConfigCatClient.ConfigChangedHandler? = nil) {
        self.autoPollIntervalInSeconds = autoPollIntervalInSeconds < 1
                ? 1
                : autoPollIntervalInSeconds
        self.maxInitWaitTimeInSeconds = maxInitWaitTimeInSeconds < 1
                ? 1
                : maxInitWaitTimeInSeconds
        self.onConfigChanged = onConfigChanged
    }
    
    var identifier: String { get { "a" } }
}

class LazyLoadingMode : PollingMode {
    let cacheRefreshIntervalInSeconds: Int
    
    init(cacheRefreshIntervalInSeconds: Int = 60) {
        self.cacheRefreshIntervalInSeconds = cacheRefreshIntervalInSeconds < 1
                ? 1
                : cacheRefreshIntervalInSeconds
    }

    var identifier: String { get { "l" } }
}

class ManualPollingMode : PollingMode {
    var identifier: String { get { "m" } }
}