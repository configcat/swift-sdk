import Foundation
import os.log

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
    private let flagEvaluator: FlagEvaluator
    private let configService: ConfigService?
    private let sdkKey: String
    private let overrideDataSource: OverrideDataSource?
    private var closed: Bool = false
    private var defaultUser: ConfigCatUser?

    private static let mutex = Mutex()
    private static var instances: [String: Weak<ConfigCatClient>] = [:]

    init(sdkKey: String,
         pollingMode: PollingMode,
         httpEngine: HttpEngine?,
         hooks: Hooks? = nil,
         configCache: ConfigCache? = nil,
         baseUrl: String = "",
         dataGovernance: DataGovernance = DataGovernance.global,
         flagOverrides: OverrideDataSource? = nil,
         defaultUser: ConfigCatUser? = nil,
         logLevel: LogLevel = .warning,
         offline: Bool = false) {
        
        assert(!sdkKey.isEmpty, "sdkKey cannot be empty")

        self.sdkKey = sdkKey
        self.hooks = hooks ?? Hooks()
        self.defaultUser = defaultUser
        log = Logger(level: logLevel, hooks: self.hooks)
        overrideDataSource = flagOverrides
        flagEvaluator = FlagEvaluator(log: log, evaluator: RolloutEvaluator(logger: log), hooks: self.hooks)

        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            // configService is not needed in localOnly mode
            configService = nil
            hooks?.invokeOnReady(state: .hasLocalOverrideFlagDataOnly)
        } else {
            let fetcher = ConfigFetcher(httpEngine: httpEngine ?? URLSessionEngine(session: URLSession(configuration: URLSessionConfiguration.default)),
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
        defer { mutex.unlock() }

        if let client = instances[sdkKey]?.get() {
            if options != nil {
                client.log.warning(eventId: 3000, message: String(format: "There is an existing client instance for the specified SDK Key. "
                    + "No new client instance will be created and the specified configuration action is ignored. "
                    + "Returning the existing client instance. SDK Key: '%@'.",
                    sdkKey))
            }
            return client
        }
        let opts = options ?? ConfigCatOptions.default
        let client = ConfigCatClient(sdkKey: sdkKey,
                pollingMode: opts.pollingMode,
                httpEngine: URLSessionEngine(session: URLSession(configuration: opts.sessionConfiguration)),
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

    /**
     Creates a new or gets an already existing ConfigCatClient for the given sdkKey.

     - Parameters:
       - sdkKey: the SDK Key for to communicate with the ConfigCat services.
       - configurator: the configuration callback.
     - Returns: the ConfigCatClient instance.
     */
    @objc public static func get(sdkKey: String, configurator: (ConfigCatOptions) -> ()) -> ConfigCatClient {
        let options = ConfigCatOptions.default
        configurator(options)
        return get(sdkKey: sdkKey, options: options)
    }

    /// Closes all ConfigCatClient instances.
    @objc public static func closeAll() {
        mutex.lock()
        defer { mutex.unlock() }

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
        defer { ConfigCatClient.mutex.unlock() }

        closeResources()
        if let weakClient = ConfigCatClient.instances[sdkKey], weakClient.get() == self {
            ConfigCatClient.instances.removeValue(forKey: sdkKey)
        }
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
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser
        
        if let _ = flagEvaluator.validateFlagType(of: Value.self, key: key, defaultValue: defaultValue, user: evalUser) {
            completion(defaultValue)
            return
        }
        
        getSettings { result in
            let evalDetails = self.flagEvaluator.evaluateFlag(result: result, key: key, defaultValue: defaultValue, user: evalUser)
            completion(evalDetails.value)
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
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser
        
        if let error = flagEvaluator.validateFlagType(of: Value.self, key: key, defaultValue: defaultValue, user: evalUser) {
            completion(TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: error, user: evalUser))
            return
        }
        
        getSettings { result in
            let evalDetails = self.flagEvaluator.evaluateFlag(result: result, key: key, defaultValue: defaultValue, user: evalUser)
            completion(evalDetails)
        }
    }

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the feature flag or setting is evaluated.
     */
    @objc public func getAllValueDetails(user: ConfigCatUser? = nil, completion: @escaping ([EvaluationDetails]) -> ()) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning empty array.")
                completion([])
                return
            }
            var detailsResult = [EvaluationDetails]()
            for key in result.settings.keys {
                guard let setting = result.settings[key] else {
                    continue
                }
                let details = self.flagEvaluator.evaluateRules(for: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
                detailsResult.append(details)
            }
            completion(detailsResult)
        }
    }

    /// Gets all the setting keys asynchronously.
    @objc public func getAllKeys(completion: @escaping ([String]) -> ()) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning empty array.")
                completion([])
                return
            }
            completion([String](result.settings.keys))
        }
    }

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @objc public func getKeyAndValue(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning nil.")
                completion(nil)
                return
            }
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

            self.log.error(eventId: 2011, message: String(format: "Could not find the setting for the specified variation ID: '%@'.", variationId))
            completion(nil)
        }
    }

    /// Gets the values of all feature flags or settings asynchronously.
    @objc public func getAllValues(user: ConfigCatUser? = nil, completion: @escaping ([String: Any]) -> ()) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning empty array.")
                completion([:])
                return
            }        
            var allValues = [String: Any]()
            for key in result.settings.keys {
                guard let setting = result.settings[key] else {
                    continue
                }
                let details = self.flagEvaluator.evaluateRules(for: setting, key: key, user: user ?? self.defaultUser, fetchTime: result.fetchTime)
                allValues[key] = details.value
            }
            completion(allValues)
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
            let message = "Client is configured to use local-only mode, thus `.refresh()` has no effect."
            log.warning(eventId: 3202, message: message)
            completion(RefreshResult(success: false, error: message))
        }
    }
    
    @objc public func snapshot() -> ConfigCatSnapshot {
        return ConfigCatSnapshot(flagEvaluator: flagEvaluator, settingsSnapshot: getInMemorySettings(), defaultUser: defaultUser, log: log)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @discardableResult
    public func waitForReady() async -> ClientReadyState {
        await withCheckedContinuation { continuation in
            guard let configService = self.configService else {
                continuation.resume(returning: .hasLocalOverrideFlagDataOnly)
                return
            }
            configService.onReady { state in
                continuation.resume(returning: state)
            }
        }
    }
    #endif

    func getSettings(completion: @escaping (SettingResult) -> Void) {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            completion(SettingResult(settings: overrideDataSource.getOverrides(), fetchTime: .distantPast))
            return
        }
        guard let configService = configService else {
            completion(SettingResult.empty)
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
    
    func getInMemorySettings() -> SettingResult {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            return SettingResult(settings: overrideDataSource.getOverrides(), fetchTime: .distantPast)
        }
        guard let configService = configService else {
            return SettingResult.empty
        }
        
        let inMemory = configService.inMemory
        
        if let overrideDataSource = overrideDataSource {
            if overrideDataSource.behaviour == .localOverRemote {
                return SettingResult(settings: inMemory.config.entries.merging(overrideDataSource.getOverrides()) { (_, new) in
                    new
                }, fetchTime: inMemory.fetchTime)
            }
            if overrideDataSource.behaviour == .remoteOverLocal {
                return SettingResult(settings: inMemory.config.entries.merging(overrideDataSource.getOverrides()) { (current, _) in
                    current
                }, fetchTime: inMemory.fetchTime)
            }
        }
        
        return SettingResult(settings: inMemory.config.entries, fetchTime: inMemory.fetchTime)
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
}
