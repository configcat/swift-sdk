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
    private static var instances: [String: ConfigCatClient] = [:]

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
        self.init(sdkKey: sdkKey, refreshMode: refreshMode, session: URLSession(configuration: sessionConfiguration),
                configCache: configCache, baseUrl: baseUrl, dataGovernance: dataGovernance, flagOverrides: flagOverrides, logLevel: logLevel)
    }

    init(sdkKey: String,
         refreshMode: PollingMode,
         session: URLSession?,
         hooks: Hooks? = nil,
         configCache: ConfigCache? = nil,
         baseUrl: String = "",
         dataGovernance: DataGovernance = DataGovernance.global,
         flagOverrides: OverrideDataSource? = nil,
         defaultUser: ConfigCatUser? = nil,
         logLevel: LogLevel = .warning) {
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
                    mode: refreshMode.identifier,
                    dataGovernance: dataGovernance,
                    baseUrl: baseUrl)

            configService = ConfigService(log: log,
                    fetcher: fetcher,
                    cache: configCache,
                    pollingMode: refreshMode,
                    hooks: self.hooks,
                    sdkKey: sdkKey)
        }
    }

    /**
     Creates a new or gets an already existing ConfigCatClient for the given sdkKey.

     - Parameters:
       - sdkKey: the SDK Key for to communicate with the ConfigCat services.
       - options: the configuration options.
     - Returns: the ConfigCatClient instance.
     */
    @objc public static func get(sdkKey: String, options: ClientOptions = ClientOptions.default) -> ConfigCatClient {
        mutex.lock()
        defer { mutex.unlock() }
        if let client = instances[sdkKey] {
            if options != ClientOptions.default {
                client.log.warning(message: """
                                            Client for '%{public}@' is already created and will be reused; options passed are being ignored.
                                            """, sdkKey)
            }
            return client
        }
        let client = ConfigCatClient(sdkKey: sdkKey,
                refreshMode: options.refreshMode,
                session: URLSession(configuration: options.sessionConfiguration),
                hooks: options.hooks,
                configCache: options.configCache,
                baseUrl: options.baseUrl,
                dataGovernance: options.dataGovernance,
                flagOverrides: options.flagOverrides,
                defaultUser: options.defaultUser,
                logLevel: options.logLevel)
        instances[sdkKey] = client
        return client
    }

    /// Closes all ConfigCatClient instances.
    @objc public static func closeAll() {
        mutex.lock()
        defer { mutex.unlock() }
        for item in instances {
            item.value.closeResources()
        }
        instances.removeAll()
    }

    /// Hooks for subscribing events.
    @objc public let hooks: Hooks

    /// Closes the underlying resources.
    @objc public func close() {
        ConfigCatClient.mutex.lock()
        defer { ConfigCatClient.mutex.unlock() }
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
        getSettings { result in
            completion(self.getValueFromSettings(result: result, key: key, defaultValue: defaultValue, user: user ?? self.defaultUser))
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
        getSettings { result in
            completion(self.getValueDetailsFromSettings(result: result, key: key, defaultValue: defaultValue))
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
            completion(self.getVariationIdFromSettings(result: result, key: key, defaultVariationId: defaultVariationId, user: user ?? self.defaultUser))
        }
    }

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    @objc public func getAllVariationIds(user: ConfigCatUser? = nil, completion: @escaping ([String]) -> ()) {
        getSettings { result in
            completion(self.getAllVariationIdsFromSettings(result: result, user: user ?? self.defaultUser))
        }
    }

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @objc public func getKeyAndValue(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        getSettings { result in
            completion(self.getKeyAndValueFromSettings(result: result, variationId: variationId))
        }
    }

    /// Gets the values of all feature flags or settings asynchronously.
    @objc public func getAllValues(user: ConfigCatUser? = nil, completion: @escaping ([String: Any]) -> ()) {
        getSettings { result in
            completion(self.getAllValuesFromSettings(result: result, user: user ?? self.defaultUser))
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
            log.warning(message: "The ConfigCat SDK is in local-only mode. Calling .refresh() has no effect.")
            completion(RefreshResult(success: false, error: "The ConfigCat SDK is in local-only mode. Calling .refresh() has no effect."))
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
    @objc public var isOffline: Bool {get {configService?.isOffline ?? true}}

    func getValueFromSettings<Value>(result: SettingResult, key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
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
            log.error(message: "Only String, Integer, Double, Bool or Any types are supported.")
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                    value: defaultValue,
                    error: "Only String, Integer, Double, Bool or Any types are supported."))
            return defaultValue
        }
        if result.settings.isEmpty {
            log.error(message: "Config is not present. Returning defaultValue: [%{public}@].", "\(defaultValue)");
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                    value: defaultValue,
                    error: String(format: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)")))
            return defaultValue
        }

        let (value, variationId, evaluateLog, rolloutRule, percentageRule): (Value?, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: result.settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: "%{public}@", evaluateLog)
        }
        if let value = value {
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails(key: key,
                    value: value,
                    variationId: variationId ?? "",
                    fetchTime: result.fetchTime,
                    user: user,
                    matchedEvaluationRule: rolloutRule,
                    matchedEvaluationPercentageRule: percentageRule))
            return value
        }

        log.error(message: """
                           Evaluating the value for the key '%{public}@' failed.
                           Returning defaultValue: [%{public}@].
                           Here are the available keys: %{public}@
                           """, key, "\(defaultValue)", [String](result.settings.keys))

        hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                value: defaultValue,
                error: String(format: """
                                      Evaluating the value for the key '%@' failed.
                                      Returning defaultValue: [%@].
                                      Here are the available keys: %@
                                      """, key, "\(defaultValue)", [String](result.settings.keys))))
        return defaultValue
    }

    func getValueDetailsFromSettings<Value>(result: SettingResult, key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> TypedEvaluationDetails<Value> {
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
            log.error(message: "Only String, Integer, Double, Bool or Any types are supported.")
            let message = "Only String, Integer, Double, Bool or Any types are supported."
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message)
        }
        if result.settings.isEmpty {
            log.error(message: "Config is not present. Returning defaultValue: [%{public}@].", "\(defaultValue)");
            let message = String(format: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)")
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message)
        }
        let (value, variationId, evaluateLog, rolloutRule, percentageRule): (Value?, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: result.settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: "%{public}@", evaluateLog)
        }
        if let value = value {
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails(key: key,
                    value: value,
                    variationId: variationId ?? "",
                    fetchTime: result.fetchTime,
                    user: user,
                    matchedEvaluationRule: rolloutRule,
                    matchedEvaluationPercentageRule: percentageRule))
            return TypedEvaluationDetails<Value>(key: key,
                    value: value,
                    variationId: variationId ?? "",
                    fetchTime: result.fetchTime,
                    user: user,
                    matchedEvaluationRule: rolloutRule,
                    matchedEvaluationPercentageRule: percentageRule)
        }
        log.error(message: """
                           Evaluating the value for the key '%{public}@' failed.
                           Returning defaultValue: [%{public}@].
                           Here are the available keys: %{public}@
                           """, key, "\(defaultValue)", [String](result.settings.keys))
        let message = String(format: """
                                     Evaluating the value for the key '%@' failed.
                                     Returning defaultValue: [%@].
                                     Here are the available keys: %@
                                     """, key, "\(defaultValue)", [String](result.settings.keys))
        hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key, value: defaultValue, error: message))
        return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message)
    }

    func getVariationIdFromSettings(result: SettingResult, key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let (_, variationId, evaluateLog, _, _): (Any?, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: result.settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: "%{public}@", evaluateLog)
        }
        if let variationId = variationId {
            return variationId
        }
        log.error(message: """
                           Evaluating the variation id for the key '%{public}@' failed.
                           Returning defaultVariationId: %{public}@
                           Here are the available keys: %{public}@
                           """, key, defaultVariationId ?? "nil", [String](result.settings.keys))
        return defaultVariationId
    }

    func getAllVariationIdsFromSettings(result: SettingResult, user: ConfigCatUser? = nil) -> [String] {
        var variationIds = [String]()
        for key in result.settings.keys {
            let (_, variationId, evaluateLog, _, _): (Any?, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: result.settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                log.info(message: "%{public}@", evaluateLog)
            }
            if let variationId = variationId {
                variationIds.append(variationId)
            } else {
                log.error(message: "Evaluating the variation id for the key '%{public}@' failed.", key)
            }
        }
        return variationIds
    }

    func getAllValuesFromSettings(result: SettingResult, user: ConfigCatUser? = nil) -> [String: Any] {
        var allValues = [String: Any]()
        for key in result.settings.keys {
            let (value, variationId, evaluateLog, rolloutRule, percentageRule): (Any?, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: result.settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                log.info(message: "%{public}@", evaluateLog)
            }
            if let value = value {
                hooks.invokeOnFlagEvaluated(details: EvaluationDetails(key: key,
                        value: value,
                        variationId: variationId ?? "",
                        fetchTime: result.fetchTime,
                        user: user,
                        matchedEvaluationRule: rolloutRule,
                        matchedEvaluationPercentageRule: percentageRule))
                allValues[key] = value
            } else {
                log.error(message: "Evaluating the value for the key '%{public}@' failed.", key)
            }
        }
        return allValues
    }

    func getKeyAndValueFromSettings(result: SettingResult, variationId: String) -> KeyValue? {
        for (key, setting) in result.settings {
            if variationId == setting.variationId {
                return KeyValue(key: key, value: setting.value)
            }
            for rule in setting.rolloutRules {
                if variationId == rule.variationId {
                    return KeyValue(key: key, value: rule.value)
                }
            }
            for rule in setting.percentageItems {
                if variationId == rule.variationId {
                    return KeyValue(key: key, value: rule.value)
                }
            }
        }

        log.error(message: "Could not find the setting for the given variationId: '%{public}@'", variationId);
        return nil
    }
}