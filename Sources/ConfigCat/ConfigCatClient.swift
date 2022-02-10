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
    fileprivate let parser: ConfigParser
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
     - Parameter flagOverrides: An OverrideDataSource implementation used to override feature flags & settings.
     - Parameter baseUrl: use this if you want to use a proxy server between your application and ConfigCat.
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
    
    internal init(sdkKey: String,
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
        self.parser = ConfigParser(logger: self.log, evaluator: RolloutEvaluator(logger: self.log))
        let cache = configCache ?? InMemoryConfigCache()
        let mode = refreshMode ?? PollingModes.autoPoll(autoPollIntervalInSeconds: 60)
        let configJsonCache = ConfigJsonCache(logger: self.log)
        let fetcher = ConfigFetcher(session: session ?? URLSession(configuration: URLSessionConfiguration.default),
                                    logger: self.log,
                                    configJsonCache: configJsonCache,
                                    sdkKey: sdkKey,
                                    mode: mode.getPollingIdentifier(),
                                    dataGovernance: dataGovernance,
                                    baseUrl: baseUrl)
        
        self.refreshPolicy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: cache, logger: self.log, configJsonCache: configJsonCache, sdkKey: sdkKey))
    }

    deinit {
        ConfigCatClient.sdkKeys.remove(sdkKey)
    }

    internal func getSettingsAsync() -> AsyncResult<[String: Any]> {
        if let overrideDataSource = self.overrideDataSource {
            switch overrideDataSource.behaviour {
            case .localOnly:
                return AsyncResult<[String:Any]>.completed(result: overrideDataSource.getOverrides())
            case .localOverRemote:
                self.refreshPolicy.getSettings()
                    .apply(completion: { settings in
                        return settings.merging(overrideDataSource.getOverrides()) { (_, new) in new }
                    })
            case .remoteOverLocal:
                self.refreshPolicy.getSettings()
                    .apply(completion: { settings in
                        return settings.merging(overrideDataSource.getOverrides()) { (current, _) in current }
                    })
            }
        }

        return self.refreshPolicy.getSettings()
    }
    
    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) -> Value {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        do {
            let settings = try self.getSettingsAsync().get()
            return try self.parser.getValueFromSettings(for: key, settings: settings, user: user)
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
                do {
                    let result: Value = try self.parser.getValueFromSettings(for: key, settings: settings, user: user)
                    completion(result)
                } catch {
                    self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
                    completion(defaultValue)
                }
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
    
    @objc public func getAllKeysAsync(completion: @escaping ([String], Error?) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                completion([String](settings.keys), nil)
        }
    }

    @objc public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }

        do {
            let settings = try self.getSettingsAsync().get()
            return try self.parser.getVariationIdFromSettings(for: key, settings: settings, user: user)
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
                do {
                    let result: String = try self.parser.getVariationIdFromSettings(for: key, settings: settings, user: user)
                    completion(result)
                } catch {
                    self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
                    let result = defaultVariationId
                    completion(result)
                }
        }
    }

    @objc public func getAllVariationIds(user: ConfigCatUser? = nil) -> [String] {
        do {
            let settings = try self.getSettingsAsync().get()
            return self.parser.getAllVariationIdsFromSettings(settings: settings, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return []
        }
    }

    @objc public func getAllVariationIdsAsync(user: ConfigCatUser? = nil, completion: @escaping ([String], Error?) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                let result = self.parser.getAllVariationIdsFromSettings(settings: settings, user: user)
                completion(result, nil)
        }
    }

    @objc public func getKeyAndValue(for variationId: String) -> KeyValue? {
        do {
            let settings = try self.getSettingsAsync().get()
            let result = try self.parser.getKeyAndValueFromSettings(for: variationId, settings: settings)
            return KeyValue(key: result.key, value: result.value)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return nil
        }
    }

    @objc public func getKeyAndValueAsync(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                do {
                    let result = try self.parser.getKeyAndValueFromSettings(for: variationId, settings: settings)
                    completion(KeyValue(key: result.key, value: result.value))
                } catch {
                    self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
                    completion(nil)
                }
        }
    }

    @objc public func getAllValues(user: ConfigCatUser? = nil) -> [String: Any] {
        do {
            let settings = try self.getSettingsAsync().get()
            return try self.parser.getAllValuesFromSettings(settings: settings, user: user)
        } catch {
            self.log.error(message: "An error occurred during reading the configuration. %@", error.localizedDescription)
            return [:]
        }
    }

    @objc public func getAllValuesAsync(user: ConfigCatUser? = nil, completion: @escaping ([String: Any], Error?) -> ()) {
        self.getSettingsAsync()
            .apply { settings in
                do {
                    let result = try self.parser.getAllValuesFromSettings(settings: settings, user: user)
                    completion(result, nil)
                } catch {
                    self.log.error(message: "An error occurred during deserializaton. %@", error.localizedDescription)
                    completion([:], error)
                }
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
