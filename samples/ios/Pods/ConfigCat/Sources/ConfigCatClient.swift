import Foundation
import os.log

extension ConfigCatClient {
    public typealias ConfigChangedHandler = () -> ()
}

/// A client for handling configurations provided by ConfigCat.
public final class ConfigCatClient : NSObject, ConfigCatClientProtocol {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigCatClient.self).bundleIdentifier!, category: "ConfigCat Client")
    fileprivate static let parser = ConfigParser()
    fileprivate let refreshPolicy: RefreshPolicy
    fileprivate let maxWaitTimeForSyncCallsInSeconds: Int
    
    /**
     Initializes a new `ConfigCatClient`.
     
     - Parameter apiKey: the api key for to communicate with the ConfigCat services.
     - Parameter policyFactory: a function used to create the a `RefreshPolicy` implementation with the given `ConfigFetcher` and `ConfigCache`.
     - Parameter maxWaitTimeForSyncCallsInSeconds: the maximum time in seconds at most how long the synchronous calls (e.g. `client.getConfiguration(...)`) have to be blocked.
     - Parameter sessionConfiguration: the url session configuration.
     - Returns: A new `ConfigCatClient`.
     */
    @objc public convenience init(apiKey: String,
                configCache: ConfigCache? = nil,
                refreshMode: PollingMode? = nil,
                maxWaitTimeForSyncCallsInSeconds: Int = 0,
                sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                baseUrl: String = "") {
        self.init(apiKey: apiKey, refreshMode: refreshMode, session: URLSession(configuration: sessionConfiguration), configCache: configCache, maxWaitTimeForSyncCallsInSeconds: maxWaitTimeForSyncCallsInSeconds, baseUrl: baseUrl)
    }
    
    internal init(apiKey: String,
                refreshMode: PollingMode?,
                session: URLSession?,
                configCache: ConfigCache? = nil,
                maxWaitTimeForSyncCallsInSeconds: Int = 0,
                baseUrl: String = "") {
        if apiKey.isEmpty {
            assert(false, "projectSecret cannot be empty")
        }
        
        if maxWaitTimeForSyncCallsInSeconds != 0 && maxWaitTimeForSyncCallsInSeconds < 2 {
            assert(false, "maxWaitTimeForSyncCallsInSeconds cannot be less than 2")
        }
        
        let cache = configCache ?? InMemoryConfigCache()
        let mode = refreshMode ?? PollingModes.autoPoll(autoPollIntervalInSeconds: 120)
        let fetcher = ConfigFetcher(session: session!, apiKey: apiKey, mode: mode, baseUrl: baseUrl)
        
        self.refreshPolicy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: cache))
        
        self.maxWaitTimeForSyncCallsInSeconds = maxWaitTimeForSyncCallsInSeconds
    }
    
    public func getValue<Value>(for key: String, defaultValue: Value, user: User?) -> Value {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        
        do {
            let config = self.maxWaitTimeForSyncCallsInSeconds == 0
                ? try self.refreshPolicy.getConfiguration().get()
                : try self.refreshPolicy.getConfiguration().get(timeout: self.maxWaitTimeForSyncCallsInSeconds)
            
            return try ConfigCatClient.parser.parseValue(for: key, json: config,user: user)
        } catch {
            os_log("An error occurred during reading the configuration. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return self.getDefaultConfig(for: key, defaultValue: defaultValue, user: user)
        }
    }
    
    public func getValue<Value>(for key: String, defaultValue: Value) -> Value {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    
    public func getValueAsync<Value>(for key: String, defaultValue: Value, user: User?, completion: @escaping (Value) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        
        self.refreshPolicy.getConfiguration()
            .apply { config in
                do {
                    let result: Value = try ConfigCatClient.parser.parseValue(for: key, json: config, user: user)
                    completion(result)
                } catch {
                    os_log("An error occurred during deserializaton. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
                    let result = self.getDefaultConfig(for: key, defaultValue: defaultValue, user: user)
                    completion(result)
                }
            }
    }
    
    public func getValueAsync<Value>(for key: String, defaultValue: Value, completion: @escaping (Value) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: nil, completion: completion)
    }
    
    @objc public func getAllKeys() -> [String] {
        do {
            let config = self.maxWaitTimeForSyncCallsInSeconds == 0
                ? try self.refreshPolicy.getConfiguration().get()
                : try self.refreshPolicy.getConfiguration().get(timeout: self.maxWaitTimeForSyncCallsInSeconds)
            
            return try ConfigCatClient.parser.getAllKeys(json: config)
        } catch {
            os_log("An error occurred during reading the configuration. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return []
        }
    }
    
    @objc public func getAllKeysAsync(completion: @escaping ([String], Error?) -> ()) {
        self.refreshPolicy.getConfiguration()
            .apply { config in
                do {
                    let result = try ConfigCatClient.parser.getAllKeys(json: config)
                    completion(result, nil)
                } catch {
                    os_log("An error occurred during deserializaton. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
                    completion([], error)
                }
        }
    }
    
    @objc public func refresh() {
        do {
            if self.maxWaitTimeForSyncCallsInSeconds == 0 {
                self.refreshPolicy.refresh().wait()
            } else {
                try self.refreshPolicy.refresh().wait(timeout: self.maxWaitTimeForSyncCallsInSeconds)
            }
        } catch {
            os_log("An error occurred during refresh. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
        }
    }
    
    @objc public func refreshAsync(completion: @escaping () -> ()) {
        self.refreshPolicy.refresh().accept(completion: completion)
    }

    private func getDefaultConfig<Value>(for key: String, defaultValue: Value, user: User?) -> Value {
        let latest = self.refreshPolicy.lastCachedConfiguration
        return latest.isEmpty ? defaultValue : self.deserializeJson(for: key, json: latest, defaultValue: defaultValue, user: user)
    }
    
    private func deserializeJson<Value>(for key: String, json: String, defaultValue: Value, user: User?) -> Value {
        do {
            return try ConfigCatClient.parser.parseValue(for: key, json: json,user: user)
        } catch {
            os_log("An error occurred during deserializaton. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return defaultValue
        }
    }
}

/// Objectiv-C interface extension.
/// Generic parameters are not available in Objectiv-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
extension ConfigCatClient {
    @objc public func getStringValue(for key: String, defaultValue: String) -> String {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getIntValue(for key: String, defaultValue: Int) -> Int {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getDoubleValue(for key: String, defaultValue: Double) -> Double {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getBoolValue(for key: String, defaultValue: Bool) -> Bool {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }
    @objc public func getAnyValue(for key: String, defaultValue: Any) -> Any {
        return getValue(for: key, defaultValue: defaultValue, user: nil)
    }

    @objc public func getStringValue(for key: String, defaultValue: String, user: User?) -> String {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getIntValue(for key: String, defaultValue: Int, user: User?) -> Int {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getDoubleValue(for key: String, defaultValue: Double, user: User?) -> Double {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getBoolValue(for key: String, defaultValue: Bool, user: User?) -> Bool {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }
    @objc public func getAnyValue(for key: String, defaultValue: Any, user: User?) -> Any {
        return getValue(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getStringValueAsync(for key: String, defaultValue: String, completion: @escaping (String) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getIntValueAsync(for key: String, defaultValue: Int, completion: @escaping (Int) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getDoubleValueAsync(for key: String, defaultValue: Double, completion: @escaping (Double) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getBoolValueAsync(for key: String, defaultValue: Bool, completion: @escaping (Bool) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }
    @objc public func getAnyValueAsync(for key: String, defaultValue: Any, completion: @escaping (Any) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, completion: completion)
    }

    @objc public func getStringValueAsync(for key: String, defaultValue: String, user: User?, completion: @escaping (String) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getIntValueAsync(for key: String, defaultValue: Int, user: User?, completion: @escaping (Int) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getDoubleValueAsync(for key: String, defaultValue: Double, user: User?, completion: @escaping (Double) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getBoolValueAsync(for key: String, defaultValue: Bool, user: User?, completion: @escaping (Bool) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getAnyValueAsync(for key: String, defaultValue: Any, user: User?, completion: @escaping (Any) -> ()) {
        return getValueAsync(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
}
