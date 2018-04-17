import Foundation

public protocol ConfigCatClientProtocol {
    func getConfigurationJsonString() -> String    
    func getConfigurationJsonStringAsync(completion: @escaping (String) -> ())
    
    func getConfiguration<Value>(defaultValue: Value) -> Value where Value : Decodable
    func getConfigurationAsync<Value>(defaultValue: Value, completion: @escaping (Value) -> ()) where Value : Decodable
    
    func getValue<Value>(for key: String, defaultValue: Value) -> Value
    func getValueAsync<Value>(for key: String, defaultValue: Value, completion: @escaping (Value) -> ())
    
    func refresh()
    func refreshAsync(completion: @escaping () -> ())
}
