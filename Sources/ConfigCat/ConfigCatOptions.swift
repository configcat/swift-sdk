import Foundation

/// Configuration options for `ConfigCatClient`.
public final class ConfigCatOptions: NSObject {
    /**
     Default: `DataGovernance.global`. Set this parameter to be in sync with the
     Data Governance preference on the [Dashboard](https://app.configcat.com/organization/data-governance).
     (Only Organization Admins have access)
     */
    @objc public var dataGovernance: DataGovernance = .global

    /// The cache implementation used to cache the downloaded config.json.
    @objc public var configCache: ConfigCache? = UserDefaultsCache()

    /// The polling mode.
    @objc public var pollingMode: PollingMode = PollingModes.autoPoll()

    /// Custom `URLSessionConfiguration` used by the HTTP calls.
    @objc public var sessionConfiguration: URLSessionConfiguration = .default

    /// The base ConfigCat CDN url.
    @objc public var baseUrl: String = ""

    /// Feature flag and setting overrides.
    @objc public var flagOverrides: OverrideDataSource? = nil

    /// Default: `LogLevel.warning`. The internal log level.
    @objc public var logLevel: ConfigCatLogLevel = .warning
    
    /// The logger used by the SDK.
    @objc public var logger: ConfigCatLogger = OSLogger()

    /// The default user, used as fallback when there's no user parameter is passed to the getValue() method.
    @objc public var defaultUser: ConfigCatUser? = nil

    /// Hooks for events sent by ConfigCatClient.
    @objc public let hooks: Hooks = Hooks()

    /// Indicates whether the SDK should be initialized in offline mode or not.
    @objc public var offline: Bool = false

    /// The default client configuration options.
    @objc public static var `default`: ConfigCatOptions {
        get {
            ConfigCatOptions()
        }
    }
}

/// Defines the possible states of the internal cache.
@objc public enum ClientCacheState: Int {
    /// No config data is available in the internal cache.
    case noFlagData
    /// Only config data provided by local flag override is available in the internal cache.
    case hasLocalOverrideFlagDataOnly
    /// Only expired config data obtained from the external cache or the ConfigCat CDN is available in the internal cache.
    case hasCachedFlagDataOnly
    /// Up-to-date config data obtained from the external cache or the ConfigCat CDN is available in the internal cache.
    case hasUpToDateFlagData
}

/// Hooks for events sent by `ConfigCatClient`.
public final class Hooks: NSObject {
    private let mutex: Mutex = Mutex(recursive: true);
    private var readyState: ClientCacheState?
    private var onReady: [(ClientCacheState) -> ()] = []
    private var onReadyWithSnapshot: [(ConfigCatClientSnapshot) -> ()] = []
    private var onFlagEvaluated: [(EvaluationDetails) -> ()] = []
    private var onConfigChanged: [(Config) -> ()] = []
    private var onConfigChangedWithSnapshot: [(Config, ConfigCatClientSnapshot) -> ()] = []
    private var onError: [(String) -> ()] = []

    /**
     Subscribes a handler to the `onReady` hook with a `ClientCacheState` parameter.
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnReady(handler: @escaping (ClientCacheState) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        if let readyState = self.readyState {
            handler(readyState)
        } else {
            onReady.append(handler)
        }
    }
    
    /**
     Subscribes a handler to the `onReady` hook with a `ConfigCatClientSnapshot` parameter.
     
     Late subscriptions (through the `client.hooks` property) might not get notified if the client reached the ready state before the subscription.
     
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnReady(snapshotHandler: @escaping (ConfigCatClientSnapshot) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onReadyWithSnapshot.append(snapshotHandler)
    }

    /**
     Subscribes a handler to the `onFlagEvaluated` hook.
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnFlagEvaluated(handler: @escaping (EvaluationDetails) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onFlagEvaluated.append(handler)
    }

    /**
     Subscribes a handler to the `onConfigChanged` hook.
     - Parameter handler: The handler to subscribe.
     */
    @available(*, deprecated, message: "Use addOnConfigChanged(snapshotHandler:) instead.")
    @objc public func addOnConfigChanged(handler: @escaping (Config) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onConfigChanged.append(handler)
    }
    
    /**
     Subscribes a handler to the `onConfigChangedWithSnapshot` hook.
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnConfigChanged(snapshotHandler: @escaping (Config, ConfigCatClientSnapshot) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onConfigChangedWithSnapshot.append(snapshotHandler)
    }

    /**
     Subscribes a handler to the `onError` hook.
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnError(handler: @escaping (String) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onError.append(handler)
    }

    func invokeOnReady(snapshotBuilder: SnapshotBuilderProtocol, inMemoryResult: InMemoryResult) {
        mutex.lock()
        defer { mutex.unlock() }
        readyState = inMemoryResult.cacheState
        for item in onReady {
            item(inMemoryResult.cacheState);
        }
        if !onReadyWithSnapshot.isEmpty {
            let snapshot = snapshotBuilder.buildSnapshot(inMemoryResult: inMemoryResult)
            for item in onReadyWithSnapshot {
                item(snapshot);
            }
        }
    }

    func invokeOnConfigChanged(snapshotBuilder: SnapshotBuilderProtocol, inMemoryResult: InMemoryResult) {
        mutex.lock()
        defer { mutex.unlock() }
        for item in onConfigChanged {
            item(inMemoryResult.entry.config);
        }
        if !onConfigChangedWithSnapshot.isEmpty {
            let snapshot = snapshotBuilder.buildSnapshot(inMemoryResult: inMemoryResult)
            for item in onConfigChangedWithSnapshot {
                item(inMemoryResult.entry.config, snapshot);
            }
        }
    }

    func invokeOnFlagEvaluated(details: EvaluationDetails) {
        mutex.lock()
        defer { mutex.unlock() }
        for item in onFlagEvaluated {
            item(details);
        }
    }

    func invokeOnError(error: String) {
        mutex.lock()
        defer { mutex.unlock() }
        for item in onError {
            item(error);
        }
    }

    func clear() {
        mutex.lock()
        defer { mutex.unlock() }
        onError.removeAll()
        onFlagEvaluated.removeAll()
        onConfigChanged.removeAll()
        onReady.removeAll()
    }
}
