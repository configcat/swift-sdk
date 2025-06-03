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

    /// Configures the SDK to allow HTTP requests.
    func setOnline()

    /// Configures the SDK to not initiate HTTP requests and work only from its cache.
    func setOffline()

    /// True when the SDK is configured not to initiate HTTP requests, otherwise false.
    var isOffline: Bool { get }

    /**
     Initiates a force refresh asynchronously on the cached configuration.

     - Parameter completion: The function which will be called when refresh completed.
     */
    func forceRefresh(completion: @escaping (RefreshResult) -> ())
    
    /// Returns a snapshot of the current state of the feature flag data within the SDK.
    /// The snapshot allows synchronous feature flag evaluation on the captured feature flag data.
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

    /// Initiates a force refresh asynchronously on the cached configuration.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func forceRefresh() async -> RefreshResult
    
    /// Awaits for SDK initialization.
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
