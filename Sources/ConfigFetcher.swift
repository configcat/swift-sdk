import os.log
import Foundation

enum Status {
    case fetched
    case notModified
    case failure
}

/// Represents a fetch response.
public struct FetchResponse {
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

/// This class is used to fetch the latest configuration.
public class ConfigFetcher {
    fileprivate static let version: String = Bundle(for: ConfigFetcher.self).infoDictionary?["CFBundleShortVersionString"] as! String
    fileprivate static let log: OSLog = OSLog(subsystem: Bundle(for: ConfigFetcher.self).bundleIdentifier!, category: "Config Fetcher")
    fileprivate let session: URLSession
    fileprivate let url: String
    fileprivate var etag: String
    
    var mode: String
    
    /**
     Initializes a ConfigFetcher instance.
     
     - Parameter config: the url session configuration.
     - Parameter apiKey: the project secret.
     - Returns: the new ConfigFetcher instance.
     */
    public convenience init(config: URLSessionConfiguration, apiKey: String) {
        self.init(session: URLSession(configuration: config), apiKey: apiKey)
    }
    
    /**
     Initializes a ConfigFetcher instance.
     
     - Parameter session: the url session.
     - Parameter apiKey: the project secret.
     - Returns: the new ConfigFetcher instance.
     */
    public init(session: URLSession, apiKey: String) {
        self.session = session
        self.url = "https://cdn.betterconfig.com/configuration-files/" + apiKey + "/config.json"
        self.etag = ""
        self.mode = ""
    }
    
    /**
     Gets the latest configuration from the network asynchronously.
     
     - Returns: the AsyncResult which computes the fetch response.
     */
    public func getConfigurationJson() -> AsyncResult<FetchResponse> {
        let request = self.getRequest()
        let result = AsyncResult<FetchResponse>()
        
        self.session.dataTask(with: request) { data, resp, error in
            if let error = error {
                os_log("An error occured during the config fetch: %@", log: ConfigFetcher.log, type: .error, error.localizedDescription)
                result.complete(result: FetchResponse(status: .failure, body: ""))
            } else {
                let response = resp as! HTTPURLResponse
                if response.statusCode >= 200 && response.statusCode < 300 {
                    os_log("Fetch was successful: new config fetched", log: ConfigFetcher.log, type: .debug)
                    if let etag = response.allHeaderFields["Etag"] as? String {
                        self.etag = etag
                    }
                    result.complete(result: FetchResponse(status: .fetched, body: String(data: data!, encoding: .utf8)!))
                } else if response.statusCode == 304 {
                    os_log("Fetch was successful: not modified", log: ConfigFetcher.log, type: .debug)
                    result.complete(result: FetchResponse(status: .notModified, body: ""))
                } else {
                    os_log("Non success status code: %@", log: ConfigFetcher.log, type: .error, String(response.statusCode))
                    result.complete(result: FetchResponse(status: .failure, body: ""))
                }
            }
        }.resume()
        
        return result
    }
    
    private func getRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: self.url)!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("ConfigCat-Swift/" + self.mode + "-" + ConfigFetcher.version, forHTTPHeaderField: "X-ConfigCat-UserAgent")
        
        if !self.etag.isEmpty {
            request.addValue(self.etag, forHTTPHeaderField: "If-None-Match")
        }
        
        return request
    }
}
