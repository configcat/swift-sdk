import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
public protocol ConfigCatClientProtocol {
    /**
     Gets the value of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `Any` (both nullable and non-nullable).
     
     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (Value) -> ())

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `Any` (both nullable and non-nullable).

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (TypedEvaluationDetails<Value>) -> ())

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: The user object to identify the caller.
     - Parameter completion: The function which will be called when the feature flag or setting is evaluated.
     */
    func getAllValueDetails(user: ConfigCatUser?, completion: @escaping ([EvaluationDetails]) -> ())

    /// Gets all the setting keys asynchronously.
    func getAllKeys(completion: @escaping ([String]) -> ())

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    func getKeyAndValue(for variationId: String, completion: @escaping (KeyValue?) -> ())

    /// Gets the values of all feature flags or settings asynchronously.
    func getAllValues(user: ConfigCatUser?, completion: @escaping ([String: Any]) -> ())

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
    func forceRefresh(completion: @escaping (RefreshResult) -> ())
    
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

     - Parameter key: The identifier of the configuration value.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> Value

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`.

     - Parameter key: The identifier of the feature flag or setting.
     - Parameter defaultValue: In case of any failure, this value will be returned.
     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> TypedEvaluationDetails<Value>

    /**
     Gets the values along with evaluation details of all feature flags and settings.

     - Parameter user: The user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllValueDetails(user: ConfigCatUser?) async -> [EvaluationDetails]

    /// Gets all the setting keys asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllKeys() async -> [String]

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getKeyAndValue(for variationId: String) async -> KeyValue?

    /// Gets the values of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllValues(user: ConfigCatUser?) async -> [String: Any]

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
    func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ())
    func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ())
    func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ())
    func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ())
    func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ())

    func getAnyValueDetails(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (EvaluationDetails) -> ())
    func getStringValueDetails(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (StringEvaluationDetails) -> ())
    func getBoolValueDetails(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (BoolEvaluationDetails) -> ())
    func getIntValueDetails(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (IntEvaluationDetails) -> ())
    func getDoubleValueDetails(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (DoubleEvaluationDetails) -> ())
}
