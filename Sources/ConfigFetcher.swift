import os.log
import Foundation

enum Status {
    case fetched
    case notModified
    case failure
}

enum RedirectMode: Int {
    case noRedirect
    case shouldRedirect
    case forceRedirect
}

/// Represents a fetch response.
struct FetchResponse {
    fileprivate let status: Status
    
    /**
     Gets the fetched configuration value, should be used when the response
     has a `FETCHED` status code.
     
     - Returns: the fetched config.
     */
    public let body: String
    
    /**
     Gets whether a new configuration value was fetched or not.
     
     - Returns: true if a new configuration value was fetched, otherwise false.
     */
    public func isFetched() -> Bool {
        return self.status == .fetched
    }
    
    /**
     Gets whether the fetch resulted a '304 Not Modified' or not.
     
     - Returns: true if the fetch resulted a '304 Not Modified' code, otherwise false.
     */
    public func isNotModified() -> Bool {
        return self.status == .notModified
    }
    
    /**
     Gets whether the fetch failed or not.
     
     - Returns: true if the fetch is failed, otherwise false.
     */
    public func isFailed() -> Bool {
        return self.status == .failure
    }
}

class ConfigFetcher : NSObject {
    fileprivate static let version: String = Bundle(for: ConfigFetcher.self).infoDictionary?["CFBundleShortVersionString"] as! String
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigFetcher.self).bundleIdentifier!, category: "Config Fetcher")
    fileprivate let session: URLSession
    fileprivate var url: String
    fileprivate var etag: String
    fileprivate let mode: String
    fileprivate let sdkKey: String
    fileprivate let urlIsCustom: Bool
    
    static let configJsonName: String = "config_v5"
    
    static let globalBaseUrl: String = "https://cdn-global.configcat.com"
    static let euOnlyBaseUrl: String = "https://cdn-eu.configcat.com"

    public init(session: URLSession, sdkKey: String, mode: String,
                dataGovernance: DataGovernance, baseUrl: String = "") {
        self.session = session
        self.sdkKey = sdkKey
        self.urlIsCustom = !baseUrl.isEmpty
        self.url = baseUrl.isEmpty
            ? dataGovernance == DataGovernance.euOnly
                ? ConfigFetcher.euOnlyBaseUrl
                : ConfigFetcher.globalBaseUrl
            : baseUrl
        self.etag = ""
        self.mode = mode
    }

    public func getConfigurationJson() -> AsyncResult<FetchResponse> {
        return self.executeFetch(executionCount: 2)
    }
    
    private func executeFetch(executionCount: Int) -> AsyncResult<FetchResponse> {
        return self.sendFetchRequest().compose { response in
            if !response.isFetched() {
                return AsyncResult.completed(result: response)
            }
            
            do {
                guard let preferences = try ConfigParser.parsePreferences(json: response.body) else {return AsyncResult.completed(result: response)}
                guard let newUrl = preferences[Config.preferencesUrl] as? String else {return AsyncResult.completed(result: response)}
                
                if newUrl.isEmpty || newUrl == self.url {
                    return AsyncResult.completed(result: response)
                }
                
                guard let redirect = preferences[Config.preferencesRedirect] as? Int else {return AsyncResult.completed(result: response)}
                
                if self.urlIsCustom && redirect != RedirectMode.forceRedirect.rawValue {
                    return AsyncResult.completed(result: response)
                }
                
                self.url = newUrl
                
                if redirect == RedirectMode.noRedirect.rawValue {
                    return AsyncResult.completed(result: response)
                }
                
                if redirect == RedirectMode.shouldRedirect.rawValue {
                    os_log("""
                           Your dataGovernance parameter at ConfigCatClient
                           initialization is not in sync with your preferences on the ConfigCat
                           Dashboard: https://app.configcat.com/organization/data-governance.
                           Only Organization Admins can access this preference.
                           """, log: ConfigFetcher.log, type: .default)
                }
                
                if executionCount > 0 {
                    return self.executeFetch(executionCount: executionCount - 1)
                }
                
            } catch {
                os_log("An error occured during the config fetch: %@", log: ConfigFetcher.log, type: .error, error.localizedDescription)
                return AsyncResult.completed(result: response)
            }
            
            os_log("Redirect loop during config.json fetch. Please contact support@configcat.com.", log: ConfigFetcher.log, type: .error)
            return AsyncResult.completed(result: response)
        }
    }
    
    private func sendFetchRequest() -> AsyncResult<FetchResponse> {
        let request = self.getRequest()
        let result = AsyncResult<FetchResponse>()
        
        self.session.dataTask(with: request) { data, resp, error in
            if let error = error {
                os_log("An error occured during the config fetch: %@", log: ConfigFetcher.log, type: .error, error.localizedDescription)
                result.complete(result: FetchResponse(status: .failure, body: ""))
            } else {
                let response = resp as! HTTPURLResponse
                if response.statusCode >= 200 && response.statusCode < 300, let data = data {
                    os_log("Fetch was successful: new config fetched", log: ConfigFetcher.log, type: .debug)
                    if let etag = response.allHeaderFields["Etag"] as? String {
                        self.etag = etag
                    }
                    result.complete(result: FetchResponse(status: .fetched, body: String(data: data, encoding: .utf8)!))
                } else if response.statusCode == 304 {
                    os_log("Fetch was successful: not modified", log: ConfigFetcher.log, type: .debug)
                    result.complete(result: FetchResponse(status: .notModified, body: ""))
                } else {
                    os_log("""
                        Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: %@
                        """, log: ConfigFetcher.log, type: .error, String(response.statusCode))
                    result.complete(result: FetchResponse(status: .failure, body: ""))
                }
            }
        }.resume()
        
        return result
    }
    
    private func getRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: self.url + "/configuration-files/" + sdkKey + "/" + ConfigFetcher.configJsonName + ".json")!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("ConfigCat-Swift/" + self.mode + "-" + ConfigFetcher.version, forHTTPHeaderField: "X-ConfigCat-UserAgent")
        
        if !self.etag.isEmpty {
            request.addValue(self.etag, forHTTPHeaderField: "If-None-Match")
        }
        
        return request
    }
}
