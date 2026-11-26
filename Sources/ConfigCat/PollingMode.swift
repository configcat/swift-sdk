import Foundation

/// Describes a polling mode.
@objc public protocol PollingMode {
    var identifier: String { get }
}

private let maximumIntervalInSeconds = 365 * 24 * 60 * 60

class AutoPollingMode: PollingMode {
    let autoPollIntervalInSeconds: Int
    let maxInitWaitTimeInSeconds: Int

    init(autoPollIntervalInSeconds: Int, maxInitWaitTimeInSeconds: Int) {
        self.autoPollIntervalInSeconds = min(max(autoPollIntervalInSeconds, 1), maximumIntervalInSeconds)
        self.maxInitWaitTimeInSeconds = min(max(maxInitWaitTimeInSeconds, 1), maximumIntervalInSeconds)
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
        self.cacheRefreshIntervalInSeconds = min(max(cacheRefreshIntervalInSeconds, 1), maximumIntervalInSeconds)
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
