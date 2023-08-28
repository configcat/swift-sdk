import Foundation

enum RedirectMode: Int {
    case noRedirect
    case shouldRedirect
    case forceRedirect
}

enum FetchResponse: Equatable {
    case fetched(ConfigEntry)
    case notModified
    case failure(message: String, isTransient: Bool)

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
         (.failure(_, _), .failure(_, _)):
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
                self.log.warning(eventId: 3002, message: "The `dataGovernance` parameter specified at the client initialization is not in sync with the preferences on the ConfigCat Dashboard. "
                    + "Read more: https://configcat.com/docs/advanced/data-governance/")
            }
            if executionCount > 0 {
                self.executeFetch(url: newUrl, eTag: eTag, executionCount: executionCount - 1, completion: completion)
                return
            }
            self.log.error(eventId: 1104, message: "Redirection loop encountered while trying to fetch config JSON. Please contact us at https://configcat.com/support/")
            completion(response)
        })
    }

    private func sendFetchRequest(url: String, eTag: String, completion: @escaping (FetchResponse) -> Void) {
        let request = getRequest(url: url, eTag: eTag)
        httpEngine.get(request: request) { (data, resp, error) in
            if let error = error {
                var message: String
                if error._code == NSURLErrorTimedOut, let engine = self.httpEngine as? URLSessionEngine {
                    message = String(format: "Request timed out while trying to fetch config JSON. Timeout value: %.2fs", engine.session.configuration.timeoutIntervalForRequest)
                    self.log.error(eventId: 1102, message: message)
                }
                else {
                    message = String(format: "Unexpected error occurred while trying to fetch config JSON. %@", error.localizedDescription)
                    self.log.error(eventId: 1103, message: message)
                }
                completion(.failure(message: message, isTransient: true))
            } else {
                let response = resp as! HTTPURLResponse
                if response.statusCode >= 200 && response.statusCode < 300, let data = data {
                    self.log.debug(message: "Fetch was successful: new config fetched")
                    let etag = response.allHeaderFields["Etag"] as? String ?? ""
                    let jsonString = String(data: data, encoding: .utf8) ?? ""
                    let result = ConfigEntry.fromConfigJson(json: jsonString, eTag: etag, fetchTime: Date())
                    switch result {
                    case .success(let entry):
                        completion(.fetched(entry))
                    case .failure(let error):
                        let message = String(format: "Fetching config JSON was successful but the HTTP response content was invalid. "
                            + "JSON parsing failed. %@", error.localizedDescription)
                        self.log.error(eventId: 1105, message: message)
                        completion(.failure(message: message, isTransient: true))
                    }
                } else if response.statusCode == 304 {
                    self.log.debug(message: "Fetch was successful: not modified")
                    completion(.notModified)
                } else if response.statusCode == 404 || response.statusCode == 403 {
                    let message = String(format: "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey. "
                        + "Status code: %@",
                        String(response.statusCode))
                    self.log.error(eventId: 1100, message: message)
                    completion(.failure(message: message, isTransient: false))
                } else {
                    let message = String(format: "Unexpected HTTP response was received while trying to fetch config JSON: %@",
                        String(response.statusCode))
                    self.log.error(eventId: 1101, message: message)
                    completion(.failure(message: message, isTransient: true))
                }
            }
        }
    }

    private func getRequest(url: String, eTag: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url + "/configuration-files/" + sdkKey + "/" + Constants.configJsonName)!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.addValue("ConfigCat-Swift/" + mode + "-" + Constants.version, forHTTPHeaderField: "X-ConfigCat-UserAgent")
        if !eTag.isEmpty {
            request.addValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        return request
    }
}
