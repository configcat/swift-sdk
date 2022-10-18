import Foundation
import os.log

extension ConfigCatClient {
    public typealias ConfigChangedHandler = () -> ()
}

/// Describes the location of your feature flag and setting data within the ConfigCat CDN.
@objc public enum DataGovernance: Int {
    /// Select this if your feature flags are published to all global CDN nodes.
    case global
    /// Select this if your feature flags are published to CDN nodes only in the EU.
    case euOnly
}

/// A client for handling configurations provided by ConfigCat.
public final class ConfigCatClient: NSObject, ConfigCatClientProtocol {
    private let log: Logger
    private let evaluator: RolloutEvaluator
    private let configService: ConfigService?
    private let sdkKey: String
    private let overrideDataSource: OverrideDataSource?
    private var closed: Bool = false
    private var defaultUser: ConfigCatUser?

    private static let mutex = Mutex()
    private static var instances: [String: Weak<ConfigCatClient>] = [:]

    /**
     Initializes a new `ConfigCatClient`.
     
     - Parameter sdkKey: the SDK Key for to communicate with the ConfigCat services.
     - Parameter dataGovernance: default: Global. Set this parameter to be in sync with the Data Governance preference on the Dashboard:
     https://app.configcat.com/organization/data-governance
     - Parameter configCache: a cache implementation, see `ConfigCache`.
     - Parameter refreshMode: the polling mode, `autoPoll`, `lazyLoad` or `manualPoll`.
     - Parameter sessionConfiguration: the url session configuration.
     - Parameter baseUrl: use this if you want to use a proxy server between your application and ConfigCat.
     - Parameter flagOverrides: An OverrideDataSource implementation used to override feature flags & settings.
     - Parameter logLevel: default: warning. Internal log level.
     - Returns: A new `ConfigCatClient`.
     */
    @available(*, deprecated, message: "Use `ConfigCatClient.get()` instead")
    @objc public convenience init(sdkKey: String,
                                  dataGovernance: DataGovernance = DataGovernance.global,
                                  configCache: ConfigCache? = nil,
                                  refreshMode: PollingMode = PollingModes.autoPoll(),
                                  sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                                  baseUrl: String = "",
                                  flagOverrides: OverrideDataSource? = nil,
                                  logLevel: LogLevel = .warning) {
        self.init(sdkKey: sdkKey, pollingMode: refreshMode, session: URLSession(configuration: sessionConfiguration),
                configCache: configCache, baseUrl: baseUrl, dataGovernance: dataGovernance, flagOverrides: flagOverrides, logLevel: logLevel)
    }

    init(sdkKey: String,
         pollingMode: PollingMode,
         session: URLSession?,
         hooks: Hooks? = nil,
         configCache: ConfigCache? = nil,
         baseUrl: String = "",
         dataGovernance: DataGovernance = DataGovernance.global,
         flagOverrides: OverrideDataSource? = nil,
         defaultUser: ConfigCatUser? = nil,
         logLevel: LogLevel = .warning,
         offline: Bool = false) {
        if sdkKey.isEmpty {
            assert(false, "sdkKey cannot be empty")
        }

        self.sdkKey = sdkKey
        self.hooks = hooks ?? Hooks()
        self.defaultUser = defaultUser
        log = Logger(level: logLevel, hooks: self.hooks)
        overrideDataSource = flagOverrides
        evaluator = RolloutEvaluator(logger: log)

        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            // configService is not needed in localOnly mode
            configService = nil
        } else {
            let fetcher = ConfigFetcher(session: session ?? URLSession(configuration: URLSessionConfiguration.default),
                    logger: log,
                    sdkKey: sdkKey,
                    mode: pollingMode.identifier,
                    dataGovernance: dataGovernance,
                    baseUrl: baseUrl)

            configService = ConfigService(log: log,
                    fetcher: fetcher,
                    cache: configCache,
                    pollingMode: pollingMode,
                    hooks: self.hooks,
                    sdkKey: sdkKey,
                    offline: offline)
        }
    }

    /**
     Creates a new or gets an already existing ConfigCatClient for the given sdkKey.

     - Parameters:
       - sdkKey: the SDK Key for to communicate with the ConfigCat services.
       - options: the configuration options.
     - Returns: the ConfigCatClient instance.
     */
    @objc public static func get(sdkKey: String, options: ConfigCatOptions? = nil) -> ConfigCatClient {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if let client = instances[sdkKey]?.get() {
            if options != nil {
                client.log.warning(message: String(format: """
                                                           Client for '%@' is already created and will be reused; options passed are being ignored.
                                                           """, sdkKey))
            }
            return client
        }
        let opts = options ?? ConfigCatOptions.default
        let client = ConfigCatClient(sdkKey: sdkKey,
                pollingMode: opts.pollingMode,
                session: URLSession(configuration: opts.sessionConfiguration),
                hooks: opts.hooks,
                configCache: opts.configCache,
                baseUrl: opts.baseUrl,
                dataGovernance: opts.dataGovernance,
                flagOverrides: opts.flagOverrides,
                defaultUser: opts.defaultUser,
                logLevel: opts.logLevel,
                offline: opts.offline)
        instances[sdkKey] = Weak(value: client)
        return client
    }

    /// Closes all ConfigCatClient instances.
    @objc public static func closeAll() {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        for item in instances {
            item.value.get()?.closeResources()
        }
        instances.removeAll()
    }

    /// Hooks for subscribing events.
    @objc public let hooks: Hooks

    /// Closes the underlying resources.
    @objc public func close() {
        ConfigCatClient.mutex.lock()
        defer {
            ConfigCatClient.mutex.unlock()
        }
        closeResources()
        ConfigCatClient.instances.removeValue(forKey: sdkKey)
    }

    func closeResources() {
        if !closed {
            configService?.close()
            hooks.clear()
            closed = true
        }
    }

    deinit {
        close()
    }

    // MARK: ConfigCatClientProtocol

    /**
     Gets the value of a feature flag or setting identified by the given `key`.

     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the feature flag or setting is evaluated.
     */
    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil, completion: @escaping (Value) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        if Value.self != String.self &&
                   Value.self != String?.self &&
                   Value.self != Int.self &&
                   Value.self != Int?.self &&
                   Value.self != Double.self &&
                   Value.self != Double?.self &&
                   Value.self != Bool.self &&
                   Value.self != Bool?.self &&
                   Value.self != Any.self &&
                   Value.self != Any?.self {
            let message = "Only String, Integer, Double, Bool or Any types are supported."
            log.error(message: message)
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                    value: defaultValue,
                    error: message))
            completion(defaultValue)
            return
        }
        getSettings { result in
            if result.settings.isEmpty {
                let message = String(format: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)")
                self.log.error(message: message)
                self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                        value: defaultValue,
                        error: message))
                completion(defaultValue)
                return
            }
            guard let setting = result.settings[key] else {
                let message = String(format: "Value not found for key '%@'. Here are the available keys: %@", key, [String](result.settings.keys))
                self.log.error(message: message)
                self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                        value: defaultValue,
                        error: message))
                completion(defaultValue)
                return
            }

            let evalDetails = self.evaluate(setting: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
            completion(evalDetails.value as? Value ?? defaultValue)
        }
    }

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`.

     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the feature flag or setting is evaluated.
     */
    public func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil, completion: @escaping (TypedEvaluationDetails<Value>) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        if Value.self != String.self &&
                   Value.self != String?.self &&
                   Value.self != Int.self &&
                   Value.self != Int?.self &&
                   Value.self != Double.self &&
                   Value.self != Double?.self &&
                   Value.self != Bool.self &&
                   Value.self != Bool?.self &&
                   Value.self != Any.self &&
                   Value.self != Any?.self {
            let message = "Only String, Integer, Double, Bool or Any types are supported."
            log.error(message: message)
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
            completion(TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message))
            return
        }
        getSettings { result in
            if result.settings.isEmpty {
                let message = String(format: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)")
                self.log.error(message: message)
                self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
                completion(TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message))
                return
            }
            guard let setting = result.settings[key] else {
                let message = String(format: "Value not found for key '%@'. Here are the available keys: %@", key, [String](result.settings.keys))
                self.log.error(message: message)
                self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                        value: defaultValue,
                        error: message))
                completion(TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message))
                return
            }

            let details = self.evaluate(setting: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
            guard let typedValue = details.value as? Value else {
                let message = String(format: """
                                             The value '%@' cannot be converted to the requested type.
                                             Returning defaultValue: [%@].
                                             Here are the available keys: %@
                                             """, "\(details.value)", "\(defaultValue)", [String](result.settings.keys))
                self.log.error(message: message)
                self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
                completion(TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message))
                return
            }

            self.hooks.invokeOnFlagEvaluated(details: details)
            completion(TypedEvaluationDetails<Value>(key: key,
                    value: typedValue,
                    variationId: details.variationId ?? "",
                    fetchTime: result.fetchTime,
                    user: user,
                    matchedEvaluationRule: details.matchedEvaluationRule,
                    matchedEvaluationPercentageRule: details.matchedEvaluationPercentageRule))

        }
    }

    /// Gets all the setting keys asynchronously.
    @objc public func getAllKeys(completion: @escaping ([String]) -> ()) {
        getSettings { result in
            completion([String](result.settings.keys))
        }
    }

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key asynchronously.
    @objc public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil, completion: @escaping (String?) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        getSettings { result in
            if result.settings.isEmpty {
                self.log.error(message: String(format: "Config is not present. Returning defaultVariationId: [%@].", "\(defaultVariationId ?? "")"))
                completion(defaultVariationId)
                return
            }
            guard let setting = result.settings[key] else {
                self.log.error(message: String(format: "Value not found for key '%@'. Here are the available keys: %@", key, [String](result.settings.keys)))
                completion(defaultVariationId)
                return
            }

            let details = self.evaluate(setting: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
            completion(details.variationId ?? defaultVariationId)
        }
    }

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    @objc public func getAllVariationIds(user: ConfigCatUser? = nil, completion: @escaping ([String]) -> ()) {
        getSettings { result in
            var variationIds = [String]()
            for key in result.settings.keys {
                guard let setting = result.settings[key] else {
                    continue
                }
                let details = self.evaluate(setting: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
                if let variationId = details.variationId {
                    variationIds.append(variationId)
                } else {
                    self.log.error(message: String(format: "Evaluating the variation id for the key '@' failed.", key))
                }
            }
            completion(variationIds)
        }
    }

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @objc public func getKeyAndValue(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        getSettings { result in
            for (key, setting) in result.settings {
                if variationId == setting.variationId {
                    completion(KeyValue(key: key, value: setting.value))
                    return
                }
                for rule in setting.rolloutRules {
                    if variationId == rule.variationId {
                        completion(KeyValue(key: key, value: rule.value))
                        return
                    }
                }
                for rule in setting.percentageItems {
                    if variationId == rule.variationId {
                        completion(KeyValue(key: key, value: rule.value))
                        return
                    }
                }
            }

            self.log.error(message: String(format: "Could not find the setting for the given variationId: '%@'", variationId))
            completion(nil)
        }
    }

    /// Gets the values of all feature flags or settings asynchronously.
    @objc public func getAllValues(user: ConfigCatUser? = nil, completion: @escaping ([String: Any]) -> ()) {
        getSettings { result in
            var allValues = [String: Any]()
            for key in result.settings.keys {
                guard let setting = result.settings[key] else {
                    continue
                }
                let details = self.evaluate(setting: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
                allValues[key] = details.value
            }
            completion(allValues)
        }
    }

    /**
     Initiates a force refresh asynchronously on the cached configuration.

     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    @available(*, deprecated, message: "Use `forceRefresh()` instead")
    @objc public func refresh(completion: @escaping () -> ()) {
        if let configService = configService {
            configService.refresh { _ in
                completion()
            }
        } else {
            log.warning(message: "The ConfigCat SDK is in local-only mode. Calling .refresh() has no effect.")
            completion()
        }
    }

    /**
     Initiates a force refresh asynchronously on the cached configuration.

     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    @objc public func forceRefresh(completion: @escaping (RefreshResult) -> ()) {
        if let configService = configService {
            configService.refresh(completion: completion)
        } else {
            let message = "The ConfigCat SDK is in local-only mode. Calling .refresh() has no effect."
            log.warning(message: message)
            completion(RefreshResult(success: false, error: message))
        }
    }

    func getSettings(completion: @escaping (SettingResult) -> Void) {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            completion(SettingResult(settings: overrideDataSource.getOverrides(), fetchTime: .distantPast))
            return
        }
        guard let configService = configService else {
            completion(SettingResult(settings: [:], fetchTime: .distantPast))
            return
        }
        if let overrideDataSource = overrideDataSource {
            if overrideDataSource.behaviour == .localOverRemote {
                configService.settings { result in
                    completion(SettingResult(settings: result.settings.merging(overrideDataSource.getOverrides()) { (_, new) in
                        new
                    }, fetchTime: result.fetchTime))
                }
                return
            }
            if overrideDataSource.behaviour == .remoteOverLocal {
                configService.settings { result in
                    completion(SettingResult(settings: result.settings.merging(overrideDataSource.getOverrides()) { (current, _) in
                        current
                    }, fetchTime: result.fetchTime))
                }
                return
            }
        }
        configService.settings { settings in
            completion(settings)
        }
    }

    /// Sets the default user.
    @objc public func setDefaultUser(user: ConfigCatUser) {
        defaultUser = user
    }

    /// Sets the default user to null.
    @objc public func clearDefaultUser() {
        defaultUser = nil
    }

    /// Configures the SDK to allow HTTP requests.
    @objc public func setOnline() {
        configService?.setOnline()
    }

    /// Configures the SDK to not initiate HTTP requests.
    @objc public func setOffline() {
        configService?.setOffline()
    }

    /// True when the SDK is configured not to initiate HTTP requests, otherwise false.
    @objc public var isOffline: Bool {
        get {
            configService?.isOffline ?? true
        }
    }

    func evaluate(setting: Setting, key: String, user: ConfigCatUser?, fetchTime: Date) -> EvaluationDetails {
        let (value, variationId, evaluateLog, rolloutRule, percentageRule): (Any, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: setting, key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: evaluateLog)
        }
        let details = EvaluationDetails(key: key,
                value: value,
                variationId: variationId,
                fetchTime: fetchTime,
                user: user,
                matchedEvaluationRule: rolloutRule,
                matchedEvaluationPercentageRule: percentageRule)
        hooks.invokeOnFlagEvaluated(details: details)
        return details
    }
}