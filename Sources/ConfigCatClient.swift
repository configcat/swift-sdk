import Foundation
import os.log

public final class ConfigCatClient : ConfigCatClientProtocol {
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigCatClient.self).bundleIdentifier!, category: "ConfigCat Client")
    fileprivate static let parser = ConfigParser()
    fileprivate let refreshPolicy: RefreshPolicy
    fileprivate let maxWaitTimeForSyncCallsInSeconds: Int
    
    init(projectSecret: String,
         policyFactory: ((ConfigCache, ConfigFetcher) -> RefreshPolicy)? = nil,
         maxWaitTimeForSyncCallsInSeconds: Int = 0,
         sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default) {
        if projectSecret.isEmpty {
            assert(false, "projectSecret cannot be empty")
        }
        
        if maxWaitTimeForSyncCallsInSeconds != 0 && maxWaitTimeForSyncCallsInSeconds < 2 {
            assert(false, "maxWaitTimeForSyncCallsInSeconds cannot be less than 2")
        }
        
        let cache = InMemoryConfigCache()
        let fetcher = ConfigFetcher(config: sessionConfiguration, projectSecret: projectSecret)
        
        self.refreshPolicy = policyFactory?(cache, fetcher) ?? AutoPollingPolicy(cache: cache, fetcher: fetcher)
        
        self.maxWaitTimeForSyncCallsInSeconds = maxWaitTimeForSyncCallsInSeconds
    }
    
    public func getConfigurationJsonString() -> String {
        do {
            return self.maxWaitTimeForSyncCallsInSeconds == 0
                ? try self.refreshPolicy.getConfiguration().get()
                : try self.refreshPolicy.getConfiguration().get(timeout: self.maxWaitTimeForSyncCallsInSeconds)
        } catch {
            os_log("An error occurred during reading the configuration. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return self.refreshPolicy.lastCachedConfiguration
        }
    }
    
    public func getConfigurationJsonStringAsync(completion: @escaping (String) -> ()) {
        self.refreshPolicy.getConfiguration().accept(completion: completion)
    }
    
    public func getConfiguration<Value>(defaultValue: Value) -> Value where Value : Decodable {
        do {
            let config = self.maxWaitTimeForSyncCallsInSeconds == 0
                ? try self.refreshPolicy.getConfiguration().get()
                : try self.refreshPolicy.getConfiguration().get(timeout: self.maxWaitTimeForSyncCallsInSeconds)
            
            return self.deserializeJson(json: config, defaultValue: defaultValue)
        } catch {
            os_log("An error occurred during reading the configuration. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return self.getDefaultConfig(defaultValue: defaultValue)
        }
    }
    
    public func getConfigurationAsync<Value>(defaultValue: Value, completion: @escaping (Value) -> ()) where Value : Decodable {
        self.refreshPolicy.getConfiguration()
            .apply { config in
                let result = self.deserializeJson(json: config, defaultValue: defaultValue)
                completion(result)
            }
    }
    
    public func getValue<Value>(for key: String, defaultValue: Value) -> Value {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        
        do {
            let config = self.maxWaitTimeForSyncCallsInSeconds == 0
                ? try self.refreshPolicy.getConfiguration().get()
                : try self.refreshPolicy.getConfiguration().get(timeout: self.maxWaitTimeForSyncCallsInSeconds)
            
            return self.deserializeJson(for: key, json: config, defaultValue: defaultValue)
        } catch {
            os_log("An error occurred during reading the configuration. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return self.getDefaultConfig(for: key, defaultValue: defaultValue)
        }
    }
    
    public func getValueAsync<Value>(for key: String, defaultValue: Value, completion: @escaping (Value) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        
        self.refreshPolicy.getConfiguration()
            .apply { config in
                let result = self.deserializeJson(for: key, json: config, defaultValue: defaultValue)
                completion(result)
            }
    }
    
    public func refresh() {
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
    
    public func refreshAsync(completion: @escaping () -> ()) {
        self.refreshPolicy.refresh().accept(completion: completion)
    }
    
    private func getDefaultConfig<Value>(defaultValue: Value) -> Value where Value : Decodable {
        let latest = self.refreshPolicy.lastCachedConfiguration
        return latest.isEmpty ? defaultValue : self.deserializeJson(json: latest, defaultValue: defaultValue)
    }
    
    private func getDefaultConfig<Value>(for key: String, defaultValue: Value) -> Value {
        let latest = self.refreshPolicy.lastCachedConfiguration
        return latest.isEmpty ? defaultValue : self.deserializeJson(for: key, json: latest, defaultValue: defaultValue)
    }
    
    private func deserializeJson<Value>(json: String, defaultValue: Value) -> Value where Value : Decodable {
        do {
            return try ConfigCatClient.parser.parse(json: json)
        } catch {
            os_log("An error occurred during deserializaton. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return defaultValue
        }
    }
    
    private func deserializeJson<Value>(for key: String, json: String, defaultValue: Value) -> Value {
        do {
            return try ConfigCatClient.parser.parseValue(for: key, json: json)
        } catch {
            os_log("An error occurred during deserializaton. %@", log: ConfigCatClient.log, type: .error, error.localizedDescription)
            return defaultValue
        }
    }
}
