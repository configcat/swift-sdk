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
    func getValue<Value>(for key: String, defaultValue: Value, user: User?) -> Value
    
    /**
     Gets a value asynchronously as `Value` from the configuration identified by the given `key`.
     
     - Parameter for: the identifier of the configuration value.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getValueAsync<Value>(for key: String, defaultValue: Value, user: User?, completion: @escaping (Value) -> ())
    
    /// Gets all the setting keys.
    func getAllKeys() -> [String]
    
    /// Gets all the setting keys asynchronously.
    func getAllKeysAsync(completion: @escaping ([String], Error?) -> ())
    
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
    func getStringValue(for key: String, defaultValue: String, user: User?) -> String
    func getIntValue(for key: String, defaultValue: Int, user: User?) -> Int
    func getDoubleValue(for key: String, defaultValue: Double, user: User?) -> Double
    func getBoolValue(for key: String, defaultValue: Bool, user: User?) -> Bool
    func getAnyValue(for key: String, defaultValue: Any, user: User?) -> Any
    func getStringValueAsync(for key: String, defaultValue: String, completion: @escaping (String) -> ())
    func getIntValueAsync(for key: String, defaultValue: Int, completion: @escaping (Int) -> ())
    func getDoubleValueAsync(for key: String, defaultValue: Double, completion: @escaping (Double) -> ())
    func getBoolValueAsync(for key: String, defaultValue: Bool, completion: @escaping (Bool) -> ())
    func getAnyValueAsync(for key: String, defaultValue: Any, completion: @escaping (Any) -> ())
    func getStringValueAsync(for key: String, defaultValue: String, user: User?, completion: @escaping (String) -> ())
    func getIntValueAsync(for key: String, defaultValue: Int, user: User?, completion: @escaping (Int) -> ())
    func getDoubleValueAsync(for key: String, defaultValue: Double, user: User?, completion: @escaping (Double) -> ())
    func getBoolValueAsync(for key: String, defaultValue: Bool, user: User?, completion: @escaping (Bool) -> ())
    func getAnyValueAsync(for key: String, defaultValue: Any, user: User?, completion: @escaping (Any) -> ())
}
