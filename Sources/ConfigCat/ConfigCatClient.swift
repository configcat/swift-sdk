import Foundation
import os.log

/// Describes the location of your feature flag and setting data within the ConfigCat CDN.
@objc public enum DataGovernance: Int {
    /// Select this if your feature flags are published to all global CDN nodes.
    case global
    /// Select this if your feature flags are published to CDN nodes only in the EU.
    case euOnly
}

/// ConfigCat SDK client.
/// Completion handlers may run synchronously or on other threads. Swift callers must
/// explicitly hop to the appropriate actor before accessing actor-isolated state.
public final class ConfigCatClient: NSObject, ConfigCatClientProtocol {
    private let log: InternalLogger
    private let flagEvaluator: FlagEvaluator
    private let configService: ConfigService?
    private let sdkKey: String
    private let overrideDataSource: OverrideDataSource?
    private let baseUrl: String
    private let snapshotBuilder: SnapshotBuilderProtocol
    private let clientState = Locked(ClientState())

    /// This class is only used in Locked context, ensuring thread safety.
    private final class ClientState: @unchecked Sendable {
        var initialized: Bool = false
        var closed: Bool = false
    }

    /// This class owns its own mutex to protect access to its internal state.
    private final class ClientRegistry: @unchecked Sendable {
        private let mutex = Mutex()
        private var instances: [String: Weak<ConfigCatClient>] = [:]

        func withLock<Result>(_ body: (inout [String: Weak<ConfigCatClient>]) -> Result) -> Result {
            mutex.withLock { body(&instances) }
        }
    }

    private static let registry = ClientRegistry()

    init(sdkKey: String,
         pollingMode: PollingMode,
         logger: ConfigCatLogger,
         httpEngine: HttpEngine?,
         hooks: Hooks? = nil,
         configCache: ConfigCache? = nil,
         baseUrl: String = "",
         dataGovernance: DataGovernance = DataGovernance.global,
         flagOverrides: OverrideDataSource? = nil,
         defaultUser: ConfigCatUser? = nil,
         logLevel: ConfigCatLogLevel = .warning,
         offline: Bool = false) {
        
        self.sdkKey = sdkKey
        self.hooks = hooks ?? Hooks()
        log = InternalLogger(log: logger, level: logLevel, hooks: self.hooks)
        overrideDataSource = flagOverrides
        flagEvaluator = FlagEvaluator(log: log, evaluator: RolloutEvaluator(logger: log), hooks: self.hooks)
        self.snapshotBuilder = SnapshotBuilder(flagEvaluator: flagEvaluator, defaultUser: defaultUser, overrideDataSource: overrideDataSource, log: log)
        self.baseUrl = baseUrl

        if overrideDataSource?.behaviour == .localOnly || !Utils.validateSdkKey(sdkKey: sdkKey, isCustomUrl: !baseUrl.isEmpty) {
            configService = nil
        } else {
            let fetcher = ConfigFetcher(httpEngine: httpEngine ?? URLSessionEngine(session: URLSession(configuration: URLSessionConfiguration.default)),
                    logger: log,
                    sdkKey: sdkKey,
                    mode: pollingMode.identifier,
                    dataGovernance: dataGovernance,
                    baseUrl: baseUrl)

            configService = ConfigService(snapshotBuilder: snapshotBuilder,
                    log: log,
                    fetcher: fetcher,
                    cache: configCache,
                    pollingMode: pollingMode,
                    hooks: self.hooks,
                    sdkKey: sdkKey,
                    offline: offline)
        }
    }

    func start() {
        let shouldInit = clientState.withLock { state in
            guard !state.initialized && !state.closed else { return false }
            state.initialized = true
            return true
        }

        if shouldInit {
            if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
                self.hooks.invokeOnReady(snapshotBuilder: snapshotBuilder, inMemoryResult: InMemoryResult(entry: .empty, cacheState: .hasLocalOverrideFlagDataOnly))
            } else if !Utils.validateSdkKey(sdkKey: sdkKey, isCustomUrl: !baseUrl.isEmpty) {
                log.error(eventId: 0, message: "ConfigCat SDK Key '\(Utils.mask(sdkKey))' is invalid.")
                self.hooks.invokeOnReady(snapshotBuilder: snapshotBuilder, inMemoryResult: InMemoryResult(entry: .empty, cacheState: .noFlagData))
            } else {
                configService?.start()
            }
        }
    }

    /**
     Creates a new or gets an already existing `ConfigCatClient` for the given `sdkKey`.

     - Parameters:
       - sdkKey: The SDK Key for to communicate with the ConfigCat services.
       - options: The configuration options.
     - Returns: The ConfigCatClient instance.
     */
    @objc public static func get(sdkKey: String, options: ConfigCatOptions? = nil) -> ConfigCatClient {
        let isCustomUrl = !(options?.baseUrl ?? "").isEmpty
        if options?.flagOverrides == nil || options?.flagOverrides?.behaviour != .localOnly {
            assert(Utils.validateSdkKey(sdkKey: sdkKey, isCustomUrl: isCustomUrl), "invalid 'sdkKey' passed to the ConfigCatClient")
        }
        
        let (client, isNew) = registry.withLock { instances in
            if let existing = instances[sdkKey]?.get() {
                return (existing, false)
            }

            let opts = options ?? .default
            let client = ConfigCatClient(sdkKey: sdkKey,
                                     pollingMode: opts.pollingMode,
                                     logger: opts.logger,
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
            return (client, true)
        }

        if isNew {
            client.start()
        } else if options != nil {
            client.log.warning(eventId: 3000, message: String(format: "There is an existing client instance for the specified SDK Key. "
                    + "No new client instance will be created and the specified configuration action is ignored. "
                    + "Returning the existing client instance. SDK Key: '%@'.",
                    Utils.mask(sdkKey)))
        }

        return client
    }

    /**
     Creates a new or gets an already existing ConfigCatClient for the given `sdkKey`.

     - Parameters:
       - sdkKey: The SDK Key for to communicate with the ConfigCat services.
       - configurator: The configuration callback.
     - Returns: The ConfigCatClient instance.
     */
    @objc public static func get(sdkKey: String, configurator: (ConfigCatOptions) -> ()) -> ConfigCatClient {
        let options = ConfigCatOptions.default
        configurator(options)
        return get(sdkKey: sdkKey, options: options)
    }

    /// Closes all ConfigCatClient instances.
    /// Pending completion handlers may be invoked synchronously on the calling thread.
    @objc public static func closeAll() {
        let clientsToClose = registry.withLock { instances in
            let clients = instances
            instances.removeAll()
            return clients
        }

        for item in clientsToClose {
            item.value.get()?.closeResources()
        }
    }

    /// Hooks for subscribing events.
    @objc public let hooks: Hooks

    /// Closes the underlying resources.
    /// Pending completion handlers may be invoked synchronously on the calling thread.
    @objc public func close() {
        ConfigCatClient.registry.withLock { instances in
            if let weakClient = instances[sdkKey], weakClient.get() == self {
                instances.removeValue(forKey: sdkKey)
            }
        }
        closeResources()
    }

    func closeResources() {
        let isClosed = clientState.withLock { state in
            guard !state.closed else { return true }
            state.closed = true
            return false
        }

        if !isClosed {
            configService?.close()
            hooks.clear()
        }
    }

    deinit {
        close()
    }

    // MARK: ConfigCatClientProtocol

    /**
     Gets the value of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `FlagValue` (both nullable and non-nullable).

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    public func getValue<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil, completion: @escaping @Sendable (Value) -> ()) {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? snapshotBuilder.defaultUser
        
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
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `FlagValue` (both nullable and non-nullable).

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    public func getValueDetails<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil, completion: @escaping @Sendable (TypedEvaluationDetails<Value>) -> ()) {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? snapshotBuilder.defaultUser
        
        if let error = flagEvaluator.validateFlagType(of: Value.self, key: key, defaultValue: defaultValue, user: evalUser) {
            completion(TypedEvaluationDetails<Value>.fromError(value: defaultValue, details: error))
            return
        }
        
        getSettings { result in
            let evalDetails = self.flagEvaluator.evaluateFlag(result: result, key: key, defaultValue: defaultValue, user: evalUser)
            completion(evalDetails)
        }
    }

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    @objc public func getAllValueDetailsObjC(user: ConfigCatUser? = nil, completion: @escaping @Sendable ([EvaluationDetails]) -> ()) {
        getAllEvaluations(user: user) { evaluations in
            completion(evaluations.map { $0.details })
        }
    }

    private func getAllEvaluations(
        user: ConfigCatUser?,
        completion: @escaping @Sendable ([(value: FlagValue, details: EvaluationDetails)]) -> Void
    ) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning empty array.")
                completion([])
                return
            }
            var evaluations = [(value: FlagValue, details: EvaluationDetails)]()
            for key in result.settings.keys {
                guard let setting = result.settings[key] else {
                    continue
                }
                if let evaluation = self.flagEvaluator.evaluateFlag(for: setting, key: key, user: user ?? self.snapshotBuilder.defaultUser, fetchTime: result.fetchTime, settings: result.settings) {
                    evaluations.append(evaluation)
                }
            }
            completion(evaluations)
        }
    }

    /// Gets all the setting keys asynchronously.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    @objc public func getAllKeys(completion: @escaping @Sendable ([String]) -> ()) {
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
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    @objc public func getKeyAndValue(for variationId: String, completion: @escaping @Sendable (KeyValue?) -> ()) {
        getSettings { result in
            if result.isEmpty {
                self.log.error(eventId: 1000, message: "Config JSON is not present. Returning nil.")
                completion(nil)
                return
            }
            for (key, setting) in result.settings {
                if setting.settingType == .unknown {
                    self.log.error(eventId: 1002, message: "Error occurred in the `getKeyAndValue` method: Setting type of '\(key)' is invalid.")
                    completion(nil)
                    return
                }
                if let valResult = self.getValueForVariationId(variationId: variationId, setting: setting) {
                    switch valResult {
                    case .success(let val):
                        completion(KeyValue(key: key, value: val))
                        return
                    case .error(let err):
                        self.log.error(eventId: 1002, message: "Error occurred in the `getKeyAndValue` method: \(err).")
                        completion(nil)
                        return
                    }
                }
            }

            self.log.error(eventId: 2011, message: String(format: "Could not find the setting for the specified variation ID: '%@'.", variationId))
            completion(nil)
        }
    }
    
    func getValueForVariationId(variationId: String, setting: Setting) -> ValueResult? {
        if variationId == setting.variationId {
            return setting.value.toCheckedValue(settingType: setting.settingType)
        }
        for rule in setting.targetingRules {
            if let servedValue = rule.servedValue {
                if variationId == servedValue.variationId {
                    return servedValue.value.toCheckedValue(settingType: setting.settingType)
                }
            } else if !rule.percentageOptions.isEmpty {
                for opt in rule.percentageOptions {
                    if variationId == opt.variationId {
                        return opt.servedValue.toCheckedValue(settingType: setting.settingType)
                    }
                }
            } else {
                return .error("Targeting rule THEN part is missing or invalid")
            }
        }
        for opt in setting.percentageOptions {
            if variationId == opt.variationId {
                return opt.servedValue.toCheckedValue(settingType: setting.settingType)
            }
        }
        return nil
    }

    /// Gets the values of all feature flags or settings asynchronously.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    @objc public func getAllValuesObjC(user: ConfigCatUser? = nil, completion: @escaping @Sendable ([String: Any]) -> ()) {
        getAllEvaluations(user: user) { evaluations in
            var allValues = [String: Any]()
            for evaluation in evaluations {
                allValues[evaluation.details.key] = evaluation.details.value
            }
            completion(allValues)
        }
    }

    /// Gets the values of all feature flags and settings as transferable scalar values.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    public func getAllValues(user: ConfigCatUser? = nil, completion: @escaping @Sendable ([String: FlagValue]) -> Void) {
        getAllEvaluations(user: user) { evaluations in
            var values = [String: FlagValue]()
            for evaluation in evaluations {
                values[evaluation.details.key] = evaluation.value
            }
            completion(values)
        }
    }

    /// Gets transferable values and evaluation details of all feature flags and settings.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    public func getAllValueDetails(user: ConfigCatUser? = nil, completion: @escaping @Sendable ([TypedEvaluationDetails<FlagValue>]) -> Void) {
        getAllEvaluations(user: user) { evaluations in
            completion(evaluations.map { TypedEvaluationDetails(value: $0.value, details: $0.details) })
        }
    }

    /**
     Updates the internally cached config by synchronizing with the external cache (if any),
     then by fetching the latest version from the ConfigCat CDN (provided that the client is online).

     - Parameter completion: The function which will be called when refresh completed successfully.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    @objc public func forceRefresh(completion: @escaping @Sendable (RefreshResult) -> ()) {
        if let configService = configService {
            configService.refresh(completion: completion)
        } else {
            let message = "Client is configured to use the localOnly override behavior, which prevents synchronization with external cache and making HTTP requests."
            log.warning(eventId: 3202, message: message)
            completion(RefreshResult(success: false, errorCode: .localOnlyClient, error: message))
        }
    }
    
    /**
     Captures the current state of the client.
     The resulting snapshot can be used to synchronously evaluate feature flags and settings based on the captured state.
     
     The operation captures the internally cached config data.
     It does not attempt to update it by synchronizing with the external cache or by fetching the latest version from the ConfigCat CDN.
     
     Therefore, it is recommended to use snapshots in conjunction with the Auto Polling mode,
     where the SDK automatically updates the internal cache in the background.
     
     For other polling modes, you will need to manually initiate a cache
     update by invoking `.forceRefresh()`.
     */
    @objc public func snapshot() -> ConfigCatClientSnapshot {
        return snapshotBuilder.buildSnapshot(inMemoryResult: configService?.inMemory)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     Waits for the client to reach the ready state, i.e. to complete initialization.
     
     Ready state is reached as soon as the initial sync with the external cache (if any) completes.
     If this does not produce up-to-date config data, and the client is online (i.e. HTTP requests are allowed),
     the first config fetch operation is also awaited in Auto Polling mode before ready state is reported.
     
     That is, reaching the ready state usually means the client is ready to evaluate feature flags and settings.
     However, please note that this is not guaranteed. In case of initialization failure or timeout,
     the internal cache may be empty or expired even after the ready state is reported. You can verify this by
     checking the return value.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @discardableResult
    public func waitForReady() async -> ClientCacheState {
        // withCheckedContinuation sometimes crashes on iOS 18.0. See https://github.com/RevenueCat/purchases-ios/pull/4286
        await withUnsafeContinuation { continuation in
            if let configService = configService {
                configService.waitForReady { state in
                    continuation.resume(returning: state)
                }
                return
            }
            if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
                continuation.resume(returning: .hasLocalOverrideFlagDataOnly)
                return
            }
            continuation.resume(returning: .noFlagData)
        }
    }
    #endif

    func getSettings(completion: @escaping @Sendable (SettingsResult) -> Void) {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            completion(SettingsResult(settings: overrideDataSource.getOverrides(), fetchTime: .distantPast))
            return
        }
        guard let configService = configService else {
            completion(.empty)
            return
        }
        if let overrideDataSource = overrideDataSource {
            if overrideDataSource.behaviour == .localOverRemote {
                configService.settings { result in
                    completion(result.withOverrides(overrideDataSource.getOverrides(), preferOverrides: true))
                }
                return
            }
            if overrideDataSource.behaviour == .remoteOverLocal {
                configService.settings { result in
                    completion(result.withOverrides(overrideDataSource.getOverrides(), preferOverrides: false))
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
        snapshotBuilder.setDefaultUser(user: user)
    }

    /// Sets the default user to null.
    @objc public func clearDefaultUser() {
        snapshotBuilder.setDefaultUser(user: nil)
    }

    /// Configures the client to allow HTTP requests.
    @objc public func setOnline() {
        configService?.setOnline()
    }

    /// Configures the client to not initiate HTTP requests but work using the cache only.
    @objc public func setOffline() {
        configService?.setOffline()
    }

    /// Returns `true` when the client is configured not to initiate HTTP requests, otherwise `false`.
    @objc public var isOffline: Bool {
        get {
            configService?.isOffline ?? true
        }
    }
}
