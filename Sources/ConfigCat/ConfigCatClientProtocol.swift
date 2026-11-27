import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
/// Completion handlers may run synchronously or on other threads. Swift callers must
/// explicitly hop to the appropriate actor before accessing actor-isolated state.
public protocol ConfigCatClientProtocol: Sendable {
    /**
     Gets the value of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `ScalarValue` (both nullable and non-nullable).
     
     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getValue<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping @Sendable (Value) -> ())

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `ScalarValue` (both nullable and non-nullable).

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getValueDetails<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping @Sendable (TypedEvaluationDetails<Value>) -> ())

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getAllValueDetails(user: ConfigCatUser?, completion: @escaping @Sendable ([TypedEvaluationDetails<ScalarValue>]) -> ())

    /// Gets the values and evaluation details in the Objective-C representation.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getAllValueDetailsObjC(user: ConfigCatUser?, completion: @escaping @Sendable ([EvaluationDetails]) -> ())

    /// Gets all the setting keys asynchronously.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getAllKeys(completion: @escaping @Sendable ([String]) -> ())

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getKeyAndValue(for variationId: String, completion: @escaping @Sendable (KeyValue?) -> ())

    /// Gets the values of all feature flags or settings asynchronously.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getAllValues(user: ConfigCatUser?, completion: @escaping @Sendable ([String: ScalarValue]) -> ())

    /// Gets the values in the Objective-C representation.
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getAllValuesObjC(user: ConfigCatUser?, completion: @escaping @Sendable ([String: Any]) -> ())

    /// Sets the default user.
    func setDefaultUser(user: ConfigCatUser)

    /// Sets the default user to null.
    func clearDefaultUser()

    /// Configures the client to allow HTTP requests.
    func setOnline()

    /// Configures the client to not initiate HTTP requests but work using the cache only.
    func setOffline()

    /// Returns `true` when the client is configured not to initiate HTTP requests, otherwise `false`.
    var isOffline: Bool { get }

    /**
     Updates the internally cached config by synchronizing with the external cache (if any),
     then by fetching the latest version from the ConfigCat CDN (provided that the client is online).

     - Parameter completion: The function which will be called when refresh completed successfully.
     */
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func forceRefresh(completion: @escaping @Sendable (RefreshResult) -> ())
    
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
    func snapshot() -> ConfigCatClientSnapshot

    /// Async/await interface
    #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.
     `Value` must conform to `Sendable`. Use the completion API for arbitrary fallback objects.

     - Parameter key: The identifier of the configuration value.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getValue<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> Value

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`.
     `Value` must conform to `Sendable`. Use the completion API for arbitrary fallback objects.

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getValueDetails<Value: Sendable>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> TypedEvaluationDetails<Value>

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllValueDetails(user: ConfigCatUser?) async -> [TypedEvaluationDetails<ScalarValue>]

    /// Gets all the setting keys asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllKeys() async -> [String]

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getKeyAndValue(for variationId: String) async -> KeyValue?

    /// Gets the values of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllValues(user: ConfigCatUser?) async -> [String: ScalarValue]

    /**
     Updates the internally cached config by synchronizing with the external cache (if any),
     then by fetching the latest version from the ConfigCat CDN (provided that the client is online).
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func forceRefresh() async -> RefreshResult
    
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
    func waitForReady() async -> ClientCacheState
    #endif

    /// Objective-C interface
    /// Generic parameters are not available in Objective-C (getValue<Value> cannot be marked @objc)
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping @Sendable (String) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping @Sendable (Int) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping @Sendable (Double) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping @Sendable (Bool) -> ())

    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getStringValueDetails(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping @Sendable (StringEvaluationDetails) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getBoolValueDetails(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping @Sendable (BoolEvaluationDetails) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getIntValueDetails(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping @Sendable (IntEvaluationDetails) -> ())
    #if compiler(>=5.6)
    @preconcurrency
    #endif
    func getDoubleValueDetails(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping @Sendable (DoubleEvaluationDetails) -> ())
}
