import Foundation

/// Defines the public protocol of the `ConfigCatClient`.
public protocol ConfigCatClientProtocol {
    /**
     Gets the configuration as a json string synchronously.
     
     - Returns: the configuration as a json string. Returns empty string if the configuration fetch from the network fails.
     */
    func getConfigurationJsonString() -> String
    
    /**
     Gets the configuration as a json string asynchronously.
     
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getConfigurationJsonStringAsync(completion: @escaping (String) -> ())
    
    /**
     Gets the configuration synchronously parsed to a `Value` type.
     
     - Parameter defaultValue: in case of any failure, this value will be returned.
     */
    func getConfiguration<Value>(defaultValue: Value) -> Value where Value : Decodable
    
    /**
     Gets the configuration asynchronously parsed to a `Value` type.
     
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter completion: the function which will be called when the configuration is successfully fetched.
     */
    func getConfigurationAsync<Value>(defaultValue: Value, completion: @escaping (Value) -> ()) where Value : Decodable
    
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
    
    /// Initiates a force refresh synchronously on the cached configuration.
    func refresh()
    
    /**
     Initiates a force refresh asynchronously on the cached configuration.
     
     - Parameter completion: the function which will be called when refresh completed successfully.
     */
    func refreshAsync(completion: @escaping () -> ())
}
