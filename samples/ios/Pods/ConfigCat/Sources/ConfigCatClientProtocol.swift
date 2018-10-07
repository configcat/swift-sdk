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
    
    /// Initiates a force refresh synchronously on the cached configuration.
    func refresh()
    
    /**
     Initiates a force refresh asynchronously on the cached configuration.
     
     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    func refreshAsync(completion: @escaping () -> ())
}
