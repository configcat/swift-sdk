import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
public protocol ConfigCatClientProtocol {
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter key: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (Value) -> ())

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

    /**
     Initiates a force refresh asynchronously on the cached configuration.
     
     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    func refresh(completion: @escaping () -> ())

    /// Async/await interface
    #if compiler(>=5.5) && canImport(_Concurrency)
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.

     - Parameter key: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     */
    @available(macOS 10.15, iOS 13, *)
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) async -> Value

    /// Gets all the setting keys asynchronously.
    @available(macOS 10.15, iOS 13, *)
    func getAllKeys() async -> [String]

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key asynchronously.
    @available(macOS 10.15, iOS 13, *)
    func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser?) async -> String?

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, *)
    func getAllVariationIds(user: ConfigCatUser?) async -> [String]

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    @available(macOS 10.15, iOS 13, *)
    func getKeyAndValue(for variationId: String) async -> KeyValue?

    /// Gets the values of all feature flags or settings asynchronously.
    @available(macOS 10.15, iOS 13, *)
    func getAllValues(user: ConfigCatUser?) async -> [String: Any]

    // Initiates a force refresh asynchronously on the cached configuration.
    @available(macOS 10.15, iOS 13, *)
    func refresh() async
    #endif

    /// Objective-C interface
    /// Generic parameters are not available in Objective-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
    func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ())
    func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ())
    func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ())
    func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ())
    func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ())
}
