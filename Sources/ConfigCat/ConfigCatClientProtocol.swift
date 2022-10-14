import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
public protocol ConfigCatClientProtocol {
    /**
     Gets the value of a feature flag or setting identified by the given `key`.
     
     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the feature flag or setting is evaluated.
     */
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (Value) -> ())

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`.

     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the feature flag or setting is evaluated.
     */
    func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (TypedEvaluationDetails<Value>) -> ())

    /// Gets all the setting keys asynchronously.
    func getAllKeys(completion: @escaping ([String]) -> ())

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key asynchronously.
    func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser?, completion: @escaping (String?) -> ())

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    func getAllVariationIds(user: ConfigCatUser?, completion: @escaping ([String]) -> ())

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
     
     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    @available(*, deprecated, message: "Use `forceRefresh()` instead")
    func refresh(completion: @escaping () -> ())

    /**
     Initiates a force refresh asynchronously on the cached configuration.

     - Parameter completion: the function which will be called when refresh completed.
     */
    func forceRefresh(completion: @escaping (RefreshResult) -> ())

    /// Async/await interface
    #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.

     - Parameter key: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> Value

    /// Gets all the setting keys asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllKeys() async -> [String]

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser?) async -> String?

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllVariationIds(user: ConfigCatUser?) async -> [String]

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getKeyAndValue(for variationId: String) async -> KeyValue?

    /// Gets the values of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func getAllValues(user: ConfigCatUser?) async -> [String: Any]

    /// Initiates a force refresh asynchronously on the cached configuration.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func refresh() async
    #endif

    /// Objective-C interface
    /// Generic parameters are not available in Objective-C (getValue<Value> cannot be marked @objc)
    func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ())
    func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ())
    func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ())
    func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ())
    func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ())
    func getAnyValueDetails(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (EvaluationDetails) -> ())
}
