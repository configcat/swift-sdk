import Foundation

enum RedirectMode: Int {
    case noRedirect
    case shouldRedirect
    case forceRedirect
}

enum FetchResponse: Equatable {
    case fetched(ConfigEntry)
    case notModified
    case failure

    public var entry: ConfigEntry? {
        switch self {
        case .fetched(let entry):
            return entry
        default:
            return nil
        }
    }
}

func ==(lhs: FetchResponse, rhs: FetchResponse) -> Bool {
    switch (lhs, rhs) {
    case (.fetched(_), .fetched(_)),
         (.notModified, .notModified),
         (.failure, .failure):
        return true
    default:
        return false
    }
}

class ConfigFetcher: NSObject {
    private let log: Logger
    private let session: URLSession
    private let baseUrl: Synced<String>
    private let mode: String
    private let sdkKey: String
    private let urlIsCustom: Bool

    init(session: URLSession, logger: Logger, sdkKey: String, mode: String,
         dataGovernance: DataGovernance, baseUrl: String = "") {
        log = logger
        self.session = session
        self.sdkKey = sdkKey
        urlIsCustom = !baseUrl.isEmpty
        self.baseUrl = Synced(initValue: baseUrl.isEmpty
                ? dataGovernance == DataGovernance.euOnly
                ? Constants.euOnlyBaseUrl
                : Constants.globalBaseUrl
                : baseUrl)
        self.mode = mode
    }

    func fetch(eTag: String, completion: @escaping (FetchResponse) -> Void) {
        let cachedUrl = baseUrl.get()
        executeFetch(url: cachedUrl, eTag: eTag, executionCount: 2) { response in
            if let newUrl = response.entry?.config.preferences[Config.preferencesUrl] as? String, !newUrl.isEmpty && newUrl != cachedUrl {
                _ = self.baseUrl.testAndSet(expect: cachedUrl, new: newUrl)
            }
            completion(response)
        }
    }

    private func executeFetch(url: String, eTag: String, executionCount: Int, completion: @escaping (FetchResponse) -> Void) {
        sendFetchRequest(url: url, eTag: eTag, completion: { response in
            guard case .fetched(let entry) = response, !entry.config.preferences.isEmpty else {
                completion(response)
                return
            }
            guard let newUrl = entry.config.preferences[Config.preferencesUrl] as? String, !newUrl.isEmpty, newUrl != url else {
                completion(response)
                return
            }
            guard let redirect = entry.config.preferences[Config.preferencesRedirect] as? Int else {
                completion(response)
                return
            }
            if self.urlIsCustom && redirect != RedirectMode.forceRedirect.rawValue {
                completion(response)
                return
            }
            if redirect == RedirectMode.noRedirect.rawValue {
                completion(response)
                return
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
                self.executeFetch(url: newUrl, eTag: eTag, executionCount: executionCount - 1, completion: completion)
                return
            }
            self.log.error(message: "Redirect loop during config.json fetch. Please contact support@configcat.com.")
            completion(response)
        })
    }

    private func sendFetchRequest(url: String, eTag: String, completion: @escaping (FetchResponse) -> Void) {
        let request = getRequest(url: url, eTag: eTag)
        session.dataTask(with: request) { data, resp, error in
                    if let error = error {
                        var extraInfo = ""
                        if error._code == NSURLErrorTimedOut {
                            extraInfo = String(format: " Timeout interval for request: %.2f seconds.", self.session.configuration.timeoutIntervalForRequest)
                        }
                        self.log.error(message: "An error occurred during the config fetch: %@%@", error.localizedDescription, extraInfo)
                        completion(.failure)
                    } else {
                        let response = resp as! HTTPURLResponse
                        if response.statusCode >= 200 && response.statusCode < 300, let data = data {
                            self.log.debug(message: "Fetch was successful: new config fetched")
                            let etag = response.allHeaderFields["Etag"] as? String ?? ""
                            let jsonString = String(data: data, encoding: .utf8) ?? ""
                            let configResult = jsonString.parseConfigFromJson()
                            switch configResult {
                            case .success(let config):
                                completion(.fetched(ConfigEntry(jsonString: jsonString, config: config, eTag: etag, fetchTime: Date())))
                            case .failure(let error):
                                self.log.error(message: "An error occurred during JSON deserialization. %@", error.localizedDescription)
                                completion(.failure)
                            }
                        } else if response.statusCode == 304 {
                            self.log.debug(message: "Fetch was successful: not modified")
                            completion(.notModified)
                        } else {
                            self.log.error(message: """
                                                    Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: %@
                                                    """, String(response.statusCode))
                            completion(.failure)
                        }
                    }
                }
                .resume()
    }

    private func getRequest(url: String, eTag: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url + "/configuration-files/" + sdkKey + "/" + Constants.configJsonName + ".json")!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("ConfigCat-Swift/" + mode + "-" + Constants.version, forHTTPHeaderField: "X-ConfigCat-UserAgent")
        if !eTag.isEmpty {
            request.addValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        return request
    }
}
