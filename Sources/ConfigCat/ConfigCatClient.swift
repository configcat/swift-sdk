import Foundation
import os.log

extension ConfigCatClient {
    public typealias ConfigChangedHandler = () -> ()
}

/// Describes the location of your feature flag and setting data within the ConfigCat CDN.
@objc public enum DataGovernance : Int {
    /// Select this if your feature flags are published to all global CDN nodes.
    case global
    /// Select this if your feature flags are published to CDN nodes only in the EU.
    case euOnly
}

/// A client for handling configurations provided by ConfigCat.
public final class ConfigCatClient : NSObject, ConfigCatClientProtocol {
    fileprivate let log: Logger
    fileprivate let evaluator: RolloutEvaluator
    fileprivate let refreshPolicy: RefreshPolicy
    fileprivate let sdkKey: String
    fileprivate let overrideDataSource: OverrideDataSource?
    fileprivate static var sdkKeys: Set<String> = []

    /**
     Initializes a new `ConfigCatClient`.
     
     - Parameter sdkKey: the SDK Key for to communicate with the ConfigCat services.
     - Parameter dataGovernance: default: Global. Set this parameter to be in sync with the Data Governance preference on the Dashboard:
     https://app.configcat.com/organization/data-governance
     - Parameter configCache: a cache implementation, see `ConfigCache`.
     - Parameter refreshMode: the polling mode, `autoPoll`, `lazyLoad` or `manualPoll`.
     - Parameter maxWaitTimeForSyncCallsInSeconds: the maximum time in seconds at most how long the synchronous calls (e.g. `client.getConfiguration(...)`) have to be blocked.
     - Parameter sessionConfiguration: the url session configuration.
     - Parameter baseUrl: use this if you want to use a proxy server between your application and ConfigCat.
     - Parameter flagOverrides: An OverrideDataSource implementation used to override feature flags & settings.
     - Parameter logLevel: default: warning. Internal log level.
     - Returns: A new `ConfigCatClient`.
     */
    @objc public convenience init(sdkKey: String,
                dataGovernance: DataGovernance = DataGovernance.global,
                configCache: ConfigCache? = nil,
                refreshMode: PollingMode? = nil,
                sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                baseUrl: String = "",
                flagOverrides: OverrideDataSource? = nil,
                logLevel: LogLevel = .warning) {
        self.init(sdkKey: sdkKey, refreshMode: refreshMode, session: URLSession(configuration: sessionConfiguration),
                  configCache: configCache, baseUrl: baseUrl, dataGovernance: dataGovernance, flagOverrides: flagOverrides, logLevel: logLevel)
    }
    
    init(sdkKey: String,
                refreshMode: PollingMode?,
                session: URLSession?,
                configCache: ConfigCache? = nil,
                baseUrl: String = "",
                dataGovernance: DataGovernance = DataGovernance.global,
                flagOverrides: OverrideDataSource? = nil,
                logLevel: LogLevel = .warning) {
        if sdkKey.isEmpty {
            assert(false, "projectSecret cannot be empty")
        }

        self.log = Logger(level: logLevel)
        if (!ConfigCatClient.sdkKeys.insert(sdkKey).inserted) {
            self.log.warning(message: """
                                      A ConfigCat Client is already initialized with sdkKey %@.
                                      We strongly recommend you to use the ConfigCat Client as a Singleton object in your application.
                                      """, sdkKey)
        }
        self.sdkKey = sdkKey
        self.overrideDataSource = flagOverrides
        self.evaluator = RolloutEvaluator(logger: self.log)
        let mode = refreshMode ?? PollingModes.autoPoll(autoPollIntervalInSeconds: 60)
        let configJsonCache = ConfigJsonCache(logger: self.log)
        let fetcher = ConfigFetcher(session: session ?? URLSession(configuration: URLSessionConfiguration.default),
                                    logger: self.log,
                                    configJsonCache: configJsonCache,
                                    sdkKey: sdkKey,
                                    mode: mode.getPollingIdentifier(),
                                    dataGovernance: dataGovernance,
                                    baseUrl: baseUrl)
        
        self.refreshPolicy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: configCache, logger: self.log, configJsonCache: configJsonCache, sdkKey: sdkKey))
    }

    deinit {
        ConfigCatClient.sdkKeys.remove(sdkKey)
    }

    func getSettingsAsync() -> AsyncResult<[String: Any]> {
        if let overrideDataSource = self.overrideDataSource {
            switch overrideDataSource.behaviour {
            case .localOnly:
                return AsyncResult<[String: Any]>.completed(result: overrideDataSource.getOverrides())
            case .localOverRemote:
                return self.refreshPolicy.getSettings()
                    .apply(completion: { settings in
                        return settings.merging(overrideDataSource.getOverrides()) { (_, new) in new }
                    })
            case .remoteOverLocal:
                return self.refreshPolicy.getSettings()
                    .apply(completion: { settings in
                        return settings.merging(overrideDataSource.getOverrides()) { (current, _) in current }
                    })
            }
        }

        return self.refreshPolicy.getSettings()
    }

    public func getValueFromSettings<Value>(settings: [String: Any], key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
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
            self.log.error(message: "Only String, Integer, Double, Bool or Any types are supported.")
            return defaultValue
        }

        if settings.isEmpty {
            self.log.error(message: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)");
            return defaultValue
        }

        let (value, _, evaluateLog): (Value?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            self.log.info(message: "%@", evaluateLog)
        }
        if let value = value {
            return value
        }

        self.log.error(message: """
                                Evaluating the value for the key '%@' failed.
                                Returning defaultValue: [%@].
                                Here are the available keys: %@
                                """, key, "\(defaultValue)", [String](settings.keys))

        return defaultValue
    }

    public func getVariationIdFromSettings(settings: [String: Any], key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            self.log.info(message: "%@", evaluateLog)
        }
        if let variationId = variationId {
            return variationId
        }

        self.log.error(message: """
                                Evaluating the variation id for the key '%@' failed.
                                Returning defaultVariationId: %@
                                Here are the available keys: %@
                                """, key, defaultVariationId ?? "nil", [String](settings.keys))

        return defaultVariationId
    }

    public func getAllVariationIdsFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String] {
        var variationIds = [String]()
        for key in settings.keys {
            let (_, variationId, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let variationId = variationId {
                variationIds.append(variationId)
            } else {
                self.log.error(message: "Evaluating the variation id for the key '%@' failed.", key)
            }
        }
        return variationIds
    }

    public func getAllValuesFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String: Any] {
        var allValues = [String: Any]()
        for key in settings.keys {
            let (value, _, evaluateLog): (Any?, String?, String?) = self.evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                self.log.info(message: "%@", evaluateLog)
            }
            if let value = value {
                allValues[key] = value
            } else {
                self.log.error(message: "Evaluating the value for the key '%@' failed.", key)
            }
        }
        return allValues
    }

    public func getKeyAndValueFromSettings(settings: [String: Any], variationId: String) -> KeyValue? {
        for (key, json) in settings {
            if let json = json as? [String: Any], let value = json[Config.value] {
                if variationId == json[Config.variationId] as? String {
                    return KeyValue(key: key, value: value)
                }

                let rolloutRules = json[Config.rolloutRules] as? [[String: Any]] ?? []
                for rule in rolloutRules {
                    if variationId == rule[Config.variationId] as? String, let value = json[Config.value]  {
                        return KeyValue(key: key, value: value)
                    }
                }

                let rolloutPercentageItems = json[Config.rolloutPercentageItems] as? [[String: Any]] ?? []
                for rule in rolloutPercentageItems {
                    if variationId == rule[Config.variationId] as? String, let value = json[Config.value] {
                        return KeyValue(key: key, value: value)
                    }
                }
            }
        }

        self.log.error(message: "Could not find the setting for the given variationId: '%@'", variationId);
        return nil
    }

    // MARK: ConfigCatClientProtocol

    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) -> Value {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        do {
            let settings = try self.getSettingsAsync().get()
            return self.getValueFromSettings(settings: settings, key: key, defaultValue: defaultValue, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return defaultValue
        }
    }
    
    public func getValue<Value>(for key: String, defaultValue: Value) -> Value {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    
    public func getValueAsync<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (Value) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        self.getSettingsAsync()
            .apply { settings in
                let result: Value = self.getValueFromSettings(settings: settings, key: key, defaultValue: defaultValue, user: user)
                completion(result)
            }
    }
    
    public func getValueAsync<Value>(for key: String, defaultValue: Value, completion: @escaping (Value) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: nil, completion: completion)
    }
    
    @objc public func getAllKeys() -> [String] {
        do {
            let settings = try self.getSettingsAsync().get()
            return [String](settings.keys)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return []
        }
    }
    
    @objc public func getAllKeysAsync(completion: @escaping ([String]) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                completion([String](settings.keys))
        }
    }

    @objc public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        do {
            let settings = try self.getSettingsAsync().get()
            return self.getVariationIdFromSettings(settings: settings, key: key, defaultVariationId: defaultVariationId, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return defaultVariationId
        }
    }

    @objc public func getVariationIdAsync(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil, completion: @escaping (String?) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        self.getSettingsAsync()
            .apply { settings in
                completion(self.getVariationIdFromSettings(settings: settings, key: key, defaultVariationId: defaultVariationId, user: user))
        }
    }

    @objc public func getAllVariationIds(user: ConfigCatUser? = nil) -> [String] {
        do {
            let settings = try self.getSettingsAsync().get()
            return self.getAllVariationIdsFromSettings(settings: settings, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return []
        }
    }

    @objc public func getAllVariationIdsAsync(user: ConfigCatUser? = nil, completion: @escaping ([String]) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                let result = self.getAllVariationIdsFromSettings(settings: settings, user: user)
                completion(result)
        }
    }

    @objc public func getKeyAndValue(for variationId: String) -> KeyValue? {
        do {
            let settings = try self.getSettingsAsync().get()
            return self.getKeyAndValueFromSettings(settings: settings, variationId: variationId)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return nil
        }
    }

    @objc public func getKeyAndValueAsync(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                completion(self.getKeyAndValueFromSettings(settings: settings, variationId: variationId))
        }
    }

    @objc public func getAllValues(user: ConfigCatUser? = nil) -> [String: Any] {
        do {
            let settings = try self.getSettingsAsync().get()
            return self.getAllValuesFromSettings(settings: settings, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return [:]
        }
    }

    @objc public func getAllValuesAsync(user: ConfigCatUser? = nil, completion: @escaping ([String: Any]) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                completion(self.getAllValuesFromSettings(settings: settings, user: user))
        }
    }

    @objc public func refresh() {
        self.refreshPolicy.refresh().wait()
    }
    
    @objc public func refreshAsync(completion: @escaping () -> ()) {
        self.refreshPolicy.refresh().accept(completion: completion)
    }
}

/// Objectiv-C interface extension.
/// Generic parameters are not available in Objectiv-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
extension ConfigCatClient {
    @objc public func getStringValue(for key: String, defaultValue: String) -> String {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getIntValue(for key: String, defaultValue: Int) -> Int {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getDoubleValue(for key: String, defaultValue: Double) -> Double {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getBoolValue(for key: String, defaultValue: Bool) -> Bool {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getAnyValue(for key: String, defaultValue: Any) -> Any {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }

    @objc public func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?) -> String {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?) -> Int {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?) -> Double {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?) -> Bool {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?) -> Any {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getStringValueAsync(for key: String, defaultValue: String, completion: @escaping (String) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getIntValueAsync(for key: String, defaultValue: Int, completion: @escaping (Int) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getDoubleValueAsync(for key: String, defaultValue: Double, completion: @escaping (Double) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getBoolValueAsync(for key: String, defaultValue: Bool, completion: @escaping (Bool) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getAnyValueAsync(for key: String, defaultValue: Any, completion: @escaping (Any) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }

    @objc public func getStringValueAsync(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getIntValueAsync(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getDoubleValueAsync(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getBoolValueAsync(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getAnyValueAsync(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
}
