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
    public let config: Config?

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
    private static let version: String = "8.0.1"
    fileprivate let log: Logger
    fileprivate let session: URLSession
    fileprivate var url: String
    fileprivate var etag: String
    fileprivate let mode: String
    fileprivate let sdkKey: String
    fileprivate let urlIsCustom: Bool
    fileprivate let configJsonCache: ConfigJsonCache
    fileprivate var fetchingRequest: AsyncResult<FetchResponse>?

    static let configJsonName: String = "config_v5"
    
    static let globalBaseUrl: String = "https://cdn-global.configcat.com"
    static let euOnlyBaseUrl: String = "https://cdn-eu.configcat.com"

    public init(session: URLSession, logger: Logger, configJsonCache: ConfigJsonCache, sdkKey: String, mode: String,
                dataGovernance: DataGovernance, baseUrl: String = "") {
        self.log = logger
        self.configJsonCache = configJsonCache
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

    public func isFetching() -> Bool {
        guard let fetchingRequest = fetchingRequest else {return false}
        return !fetchingRequest.completed
    }
    
    public func getConfiguration() -> AsyncResult<FetchResponse> {
        return self.executeFetch(executionCount: 2)
    }
    
    private func executeFetch(executionCount: Int) -> AsyncResult<FetchResponse> {
        return self.sendFetchRequest().compose { response in
            if !response.isFetched() {
                return AsyncResult.completed(result: response)
            }
            
            guard let config = response.config else {return AsyncResult.completed(result: response)}
            guard !config.preferences.isEmpty else {return AsyncResult.completed(result: response)}
            guard let newUrl = config.preferences[Config.preferencesUrl] as? String else {return AsyncResult.completed(result: response)}

            if newUrl.isEmpty || newUrl == self.url {
                return AsyncResult.completed(result: response)
            }

            guard let redirect = config.preferences[Config.preferencesRedirect] as? Int else {return AsyncResult.completed(result: response)}

            if self.urlIsCustom && redirect != RedirectMode.forceRedirect.rawValue {
                return AsyncResult.completed(result: response)
            }

            self.url = newUrl

            if redirect == RedirectMode.noRedirect.rawValue {
                return AsyncResult.completed(result: response)
            }

            if redirect == RedirectMode.shouldRedirect.rawValue {
                self.log.warning(message: """
                       Your dataGovernance parameter at ConfigCatClient
                       initialization is not in sync with your preferences on the ConfigCat
                       Dashboard: https://app.configcat.com/organization/data-governance.
                       Only Organization Admins can access this preference.
                       """)
            }

            if executionCount > 0 {
                return self.executeFetch(executionCount: executionCount - 1)
            }
            
            self.log.error(message: "Redirect loop during config.json fetch. Please contact support@configcat.com.")
            return AsyncResult.completed(result: response)
        }
    }
    
    private func sendFetchRequest() -> AsyncResult<FetchResponse> {
        if let fetchingRequest = fetchingRequest {
            if !fetchingRequest.completed {
                self.log.debug(message: "Config fetching is skipped because there is an ongoing fetch request")
                return fetchingRequest
            }
        }

        let request = self.getRequest()
        let result = AsyncResult<FetchResponse>()
        
        self.session.dataTask(with: request) { data, resp, error in
            if let error = error {
                var extraInfo = ""
                if error._code == NSURLErrorTimedOut {
                    extraInfo = String(format: " Timeout interval for request: %.2f seconds.", self.session.configuration.timeoutIntervalForRequest)
                }
                self.log.error(message: "An error occurred during the config fetch: %@%@", error.localizedDescription, extraInfo)
                result.complete(result: FetchResponse(status: .failure, config: nil))
            } else {
                let response = resp as! HTTPURLResponse
                if response.statusCode >= 200 && response.statusCode < 300, let data = data {
                    self.log.debug(message: "Fetch was successful: new config fetched")
                    if let etag = response.allHeaderFields["Etag"] as? String {
                        self.etag = etag
                    }
                    result.complete(result: FetchResponse(status: .fetched, config: self.configJsonCache.getConfigFromJson(json: String(data: data, encoding: .utf8)!)))
                } else if response.statusCode == 304 {
                    self.log.debug(message: "Fetch was successful: not modified")
                    result.complete(result: FetchResponse(status: .notModified, config: nil))
                } else {
                    self.log.error(message: """
                        Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: %@
                        """, String(response.statusCode))
                    result.complete(result: FetchResponse(status: .failure, config: nil))
                }
            }
        }.resume()

        fetchingRequest = result
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
