import Foundation

/// Describes a polling mode.
@objc public protocol PollingMode {
    var identifier: String { get }
}

class AutoPollingMode: PollingMode {
    let autoPollIntervalInSeconds: Int
    let maxInitWaitTimeInSeconds: Int

    init(autoPollIntervalInSeconds: Int, maxInitWaitTimeInSeconds: Int) {
        self.autoPollIntervalInSeconds = autoPollIntervalInSeconds < 1
                ? 1
                : autoPollIntervalInSeconds
        self.maxInitWaitTimeInSeconds = maxInitWaitTimeInSeconds < 1
                ? 1
                : maxInitWaitTimeInSeconds
    }

    var identifier: String {
        get {
            "a"
        }
    }
}

class LazyLoadingMode: PollingMode {
    let cacheRefreshIntervalInSeconds: Int

    init(cacheRefreshIntervalInSeconds: Int) {
        self.cacheRefreshIntervalInSeconds = cacheRefreshIntervalInSeconds < 1
                ? 1
                : cacheRefreshIntervalInSeconds
    }

    var identifier: String {
        get {
            "l"
        }
    }
}

class ManualPollingMode: PollingMode {
    var identifier: String {
        get {
            "m"
        }
    }
}
