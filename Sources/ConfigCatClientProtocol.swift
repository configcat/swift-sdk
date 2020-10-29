import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
public protocol ConfigCatClientProtocol {

    /**
     Gets a value synchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter for: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     */
    func getValue<Value>(for key: String, defaultValue: Value) -> Value
    
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter for: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getValueAsync<Value>(for key: String, defaultValue: Value, completion: @escaping (Value) -> ())

    /**
     Gets a value synchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter for: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     */
    func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?) -> Value
    
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter for: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getValueAsync<Value>(for key: String, defaultValue: Value, user: ConfigCatUser?, completion: @escaping (Value) -> ())
    
    /// Gets all the setting keys.
    func getAllKeys() -> [String]
    
    /// Gets all the setting keys asynchronously.
    func getAllKeysAsync(completion: @escaping ([String], Error?) -> ())

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key.
    func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser?) -> String?

    /// Gets the Variation ID (analytics) of a feature flag or setting based on it's key asynchronously.
    func getVariationIdAsync(for key: String, defaultVariationId: String?, user: ConfigCatUser?, completion: @escaping (String?) -> ())

    /// Gets the Variation IDs (analytics) of all feature flags or settings.
    func getAllVariationIds(user: ConfigCatUser?) -> [String]

    /// Gets the Variation IDs (analytics) of all feature flags or settings asynchronously.
    func getAllVariationIdsAsync(user: ConfigCatUser?, completion: @escaping ([String], Error?) -> ())

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    func getKeyAndValue(for variationId: String) -> KeyValue?

    /// Gets the key of a setting and it's value identified by the given Variation ID (analytics)
    func getKeyAndValueAsync(for variationId: String, completion: @escaping (KeyValue?) -> ())

    /// Initiates a force refresh synchronously on the cached configuration.
    func refresh()
    
    /**
     Initiates a force refresh asynchronously on the cached configuration.
     
     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    func refreshAsync(completion: @escaping () -> ())

    /// Objectiv-C interface
    /// Generic parameters are not available in Objectiv-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
    func getStringValue(for key: String, defaultValue: String) -> String
    func getIntValue(for key: String, defaultValue: Int) -> Int
    func getDoubleValue(for key: String, defaultValue: Double) -> Double
    func getBoolValue(for key: String, defaultValue: Bool) -> Bool
    func getAnyValue(for key: String, defaultValue: Any) -> Any
    func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?) -> String
    func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?) -> Int
    func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?) -> Double
    func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?) -> Bool
    func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?) -> Any
    func getStringValueAsync(for key: String, defaultValue: String, completion: @escaping (String) -> ())
    func getIntValueAsync(for key: String, defaultValue: Int, completion: @escaping (Int) -> ())
    func getDoubleValueAsync(for key: String, defaultValue: Double, completion: @escaping (Double) -> ())
    func getBoolValueAsync(for key: String, defaultValue: Bool, completion: @escaping (Bool) -> ())
    func getAnyValueAsync(for key: String, defaultValue: Any, completion: @escaping (Any) -> ())
    func getStringValueAsync(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ())
    func getIntValueAsync(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ())
    func getDoubleValueAsync(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ())
    func getBoolValueAsync(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ())
    func getAnyValueAsync(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ())
}
