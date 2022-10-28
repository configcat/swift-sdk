import Foundation

enum RedirectMode: Int {
    case noRedirect
    case shouldRedirect
    case forceRedirect
}

enum FetchResponse: Equatable {
    case fetched(ConfigEntry)
    case notModified
    case failure(String)

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
         (.failure(_), .failure(_)):
        return true
    default:
        return false
    }
}

protocol HttpEngine {
    func get(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}

class URLSessionEngine: HttpEngine {
    fileprivate let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func get(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        session.dataTask(with: request) { (data, resp, error) in
            completion(data, resp, error)
        }.resume()
    }
}

class ConfigFetcher: NSObject {
    private let log: Logger
    private let httpEngine: HttpEngine
    @Synced private var baseUrl: String
    private let mode: String
    private let sdkKey: String
    private let urlIsCustom: Bool

    init(httpEngine: HttpEngine, logger: Logger, sdkKey: String, mode: String,
         dataGovernance: DataGovernance, baseUrl: String = "") {
        log = logger
        self.httpEngine = httpEngine
        self.sdkKey = sdkKey
        urlIsCustom = !baseUrl.isEmpty
        self.baseUrl = baseUrl.isEmpty
                ? dataGovernance == DataGovernance.euOnly
                ? Constants.euOnlyBaseUrl
                : Constants.globalBaseUrl
                : baseUrl
        self.mode = mode
    }

    func fetch(eTag: String, completion: @escaping (FetchResponse) -> Void) {
        let cachedUrl = baseUrl
        executeFetch(url: cachedUrl, eTag: eTag, executionCount: 2) { response in
            if let newUrl = response.entry?.config.preferences?.preferencesUrl, !newUrl.isEmpty && newUrl != cachedUrl {
                self._baseUrl.testAndSet(expect: cachedUrl, new: newUrl)
            }
            completion(response)
        }
    }

    private func executeFetch(url: String, eTag: String, executionCount: Int, completion: @escaping (FetchResponse) -> Void) {
        sendFetchRequest(url: url, eTag: eTag, completion: { response in
            guard case .fetched(let entry) = response else {
                completion(response)
                return
            }
            guard let newUrl = entry.config.preferences?.preferencesUrl, !newUrl.isEmpty, newUrl != url else {
                completion(response)
                return
            }
            guard let redirect = entry.config.preferences?.preferencesRedirect else {
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
        httpEngine.get(request: request) { (data, resp, error) in
            if let error = error {
                var extraInfo = ""
                if error._code == NSURLErrorTimedOut, let engine = self.httpEngine as? URLSessionEngine {
                    extraInfo = String(format: " Timeout interval for request: %.2f seconds.", engine.session.configuration.timeoutIntervalForRequest)
                }
                let message = String(format: "An error occurred during the config fetch: %@%@", error.localizedDescription, extraInfo)
                self.log.error(message: message)
                completion(.failure(message))
            } else {
                let response = resp as! HTTPURLResponse
                if response.statusCode >= 200 && response.statusCode < 300, let data = data {
                    self.log.debug(message: "Fetch was successful: new config fetched")
                    let etag = response.allHeaderFields["Etag"] as? String ?? ""
                    let jsonString = String(data: data, encoding: .utf8) ?? ""
                    let configResult = self.parseConfigFromJson(json: jsonString)
                    switch configResult {
                    case .success(let config):
                        completion(.fetched(ConfigEntry(config: config, eTag: etag, fetchTime: Date())))
                    case .failure(let error):
                        let message = String(format: "An error occurred during JSON deserialization. %@", error.localizedDescription)
                        self.log.error(message: message)
                        completion(.failure(message))
                    }
                } else if response.statusCode == 304 {
                    self.log.debug(message: "Fetch was successful: not modified")
                    completion(.notModified)
                } else {
                    let message = String(format: """
                                                 Double-check your SDK Key at https://app.configcat.com/sdkkey. Non success status code: %@
                                                 """, String(response.statusCode))
                    self.log.error(message: message)
                    completion(.failure(message))
                }
            }
        }
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

    private func parseConfigFromJson(json: String) -> Result<Config, Error> {
        do {
            guard let data = json.data(using: .utf8) else {
                return .failure(ParseError(message: "Decode to utf8 data failed."))
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return .failure(ParseError(message: "Convert to [String: Any] map failed."))
            }
            return .success(Config.fromJson(json: jsonObject))
        } catch {
            return .failure(error)
        }
    }
}
