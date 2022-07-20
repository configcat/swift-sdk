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

    /// Objective-C interface
    /// Generic parameters are not available in Objective-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
    func getStringValueAsync(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ())
    func getIntValueAsync(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ())
    func getDoubleValueAsync(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ())
    func getBoolValueAsync(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ())
    func getAnyValueAsync(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ())
}
