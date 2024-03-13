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

/// Describes the initialization state of the `ConfigCatClient`.
@objc public enum ClientReadyState: Int {
    /// The SDK has no feature flag data neither from the cache nor from the ConfigCat CDN.
    case noFlagData
    /// The SDK runs with local only feature flag data.
    case hasLocalOverrideFlagDataOnly
    /// The SDK has feature flag data to work with only from the cache.
    case hasCachedFlagDataOnly
    /// The SDK works with the latest feature flag data received from the ConfigCat CDN.
    case hasUpToDateFlagData
}

/// Hooks for events sent by `ConfigCatClient`.
public final class Hooks: NSObject {
    private let mutex: Mutex = Mutex(recursive: true);
    private var readyState: ClientReadyState?
    private var onReady: [(ClientReadyState) -> ()] = []
    private var onFlagEvaluated: [(EvaluationDetails) -> ()] = []
    private var onConfigChanged: [(ConfigProtocol) -> ()] = []
    private var onError: [(String) -> ()] = []

    /**
     Subscribes a handler to the `onReady` hook.
     - Parameter handler: The handler to subscribe.
     */
    @objc public func addOnReady(handler: @escaping (ClientReadyState) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        if let readyState = self.readyState {
            handler(readyState)
        } else {
            onReady.append(handler)
        }
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
    @objc public func addOnConfigChanged(handler: @escaping (ConfigProtocol) -> ()) {
        mutex.lock()
        defer { mutex.unlock() }
        onConfigChanged.append(handler)
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

    func invokeOnReady(state: ClientReadyState) {
        mutex.lock()
        defer { mutex.unlock() }
        readyState = state
        for item in onReady {
            item(state);
        }
    }

    func invokeOnConfigChanged(config: ConfigProtocol) {
        mutex.lock()
        defer { mutex.unlock() }
        for item in onConfigChanged {
            item(config);
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
