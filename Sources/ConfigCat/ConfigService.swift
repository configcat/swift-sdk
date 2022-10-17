import Foundation

class SettingResult {
    let settings: [String: Setting]
    let fetchTime: Date

    init(settings: [String: Setting], fetchTime: Date) {
        self.settings = settings
        self.fetchTime = fetchTime
    }
}

public final class RefreshResult: NSObject {
    @objc public let success: Bool
    @objc public let error: String?

    init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

enum FetchResult {
    case success(ConfigEntry)
    case failure(String)
}

class ConfigService {
    private let log: Logger
    private let fetcher: ConfigFetcher
    private let mutex: Mutex = Mutex(recursive: true)
    private let cache: ConfigCache?
    private let pollingMode: PollingMode
    private let hooks: Hooks
    private let cacheKey: String
    private var initialized: Bool
    private var offline: Bool = false
    private var completions: MutableQueue<(FetchResult) -> Void>?
    private var cachedEntry: ConfigEntry = .empty
    private var cachedJsonString: String = ""
    private var pollTimer: DispatchSourceTimer? = nil
    private var initTimer: DispatchSourceTimer? = nil

    init(log: Logger, fetcher: ConfigFetcher, cache: ConfigCache?, pollingMode: PollingMode, hooks: Hooks, sdkKey: String, offline: Bool) {
        self.log = log
        self.fetcher = fetcher
        self.cache = cache
        self.pollingMode = pollingMode
        self.hooks = hooks
        self.offline = offline
        let keyToHash = "swift_" + Constants.configJsonName + "_" + sdkKey
        cacheKey = String(keyToHash.sha1hex ?? keyToHash)

        if let autoPoll = pollingMode as? AutoPollingMode {
            initialized = false

            if !offline {
                startPoll(mode: autoPoll)
            }

            // Waiting for the client initialization.
            // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while the config is not ready
            // the default value will be returned.
            initTimer = DispatchSource.makeTimerSource()
            initTimer?.schedule(deadline: .now() + .seconds(autoPoll.maxInitWaitTimeInSeconds))
            initTimer?.setEventHandler(handler: { [weak self] in
                guard let this = self else {
                    return
                }
                this.mutex.lock()
                defer {
                    this.mutex.unlock()
                }

                // Max wait time expired without result, notify subscribers with the cached config.
                if !this.initialized {
                    this.log.warning(message: String(format: "Max init wait time for the very first fetch reached (%ds). Returning cached config.", autoPoll.maxInitWaitTimeInSeconds))
                    this.initialized = true
                    hooks.invokeOnReady()
                    this.callCompletions(result: .success(this.cachedEntry))
                    this.completions = nil
                }
            })
            initTimer?.resume()
        } else {
            initialized = true
            hooks.invokeOnReady()
        }
    }

    func close() {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        callCompletions(result: .success(cachedEntry))
        completions = nil
        pollTimer?.cancel()
        initTimer?.cancel()
    }

    func settings(completion: @escaping (SettingResult) -> Void) {
        switch pollingMode {
        case let lazy as LazyLoadingMode:
            fetchIfOlder(time: Date().subtract(seconds: lazy.cacheRefreshIntervalInSeconds)!) { result in
                switch result {
                case .success(let entry): completion(SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime))
                case .failure(_): completion(SettingResult(settings: self.cachedEntry.config.entries, fetchTime: self.cachedEntry.fetchTime))
                }
            }
        default:
            fetchIfOlder(time: .distantPast, preferCache: true) { result in
                switch result {
                case .success(let entry): completion(SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime))
                case .failure(_): completion(SettingResult(settings: self.cachedEntry.config.entries, fetchTime: self.cachedEntry.fetchTime))
                }
            }
        }
    }

    func refresh(completion: @escaping (RefreshResult) -> Void) {
        fetchIfOlder(time: .distantFuture) { result in
            switch result {
            case .success: completion(RefreshResult(success: true))
            case .failure(let error): completion(RefreshResult(success: false, error: error))
            }
        }
    }

    func setOnline() {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if !offline {
            return
        }
        offline = false
        if let autoPoll = pollingMode as? AutoPollingMode {
            startPoll(mode: autoPoll)
        }
        log.debug(message: "Switched to ONLINE mode.")
    }

    func setOffline() {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if offline {
            return
        }
        offline = true
        pollTimer?.cancel()
        pollTimer = nil
        log.debug(message: "Switched to OFFLINE mode.")
    }

    var isOffline: Bool {
        get {
            offline
        }
    }

    private func fetchIfOlder(time: Date, preferCache: Bool = false, completion: @escaping (FetchResult) -> Void) {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        // Sync up with the cache and use it when it's not expired.
        if cachedEntry.isEmpty || cachedEntry.fetchTime > time {
            let entry = readCache()
            if !entry.isEmpty && entry != cachedEntry {
                cachedEntry = entry
                hooks.invokeOnConfigChanged(settings: entry.config.entries)
            }
            // Cache isn't expired
            if cachedEntry.fetchTime > time {
                if !initialized {
                    initialized = true
                    hooks.invokeOnReady()
                }
                completion(.success(cachedEntry))
                return
            }
        }
        // Use cache anyway (get calls on auto & manual poll must not initiate fetch).
        // The initialized check ensures that we subscribe for the ongoing fetch during the
        // max init wait time window in case of auto poll.
        if preferCache && initialized {
            completion(.success(cachedEntry))
            return
        }
        // If we are in offline mode we are not allowed to initiate fetch.
        if offline {
            completion(.failure("The SDK is in offline mode, it can't initiate HTTP calls."))
            return
        }
        // There's an ongoing fetch running, save the callback to call it later when the ongoing fetch finishes.
        if completions != nil {
            completions?.enqueue(item: completion)
            return
        }
        // No fetch is running, initiate a new one.
        completions = MutableQueue<(FetchResult) -> Void>()
        completions?.enqueue(item: completion)
        fetcher.fetch(eTag: cachedEntry.eTag) { response in
            self.processResponse(response: response)
        }
    }

    private func processResponse(response: FetchResponse) {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        if !initialized {
            initialized = true
            hooks.invokeOnReady()
        }
        switch response {
        case .fetched(let entry):
            cachedEntry = entry
            writeCache(entry: entry)
            if let auto = pollingMode as? AutoPollingMode {
                auto.onConfigChanged?()
            }
            hooks.invokeOnConfigChanged(settings: entry.config.entries)
            callCompletions(result: .success(entry))
        case .notModified:
            cachedEntry = cachedEntry.withFetchTime(time: Date())
            writeCache(entry: cachedEntry)
            callCompletions(result: .success(cachedEntry))
        case .failure(let error):
            callCompletions(result: .failure(error))
        }
        completions = nil
    }

    private func callCompletions(result: FetchResult) {
        if let completions = completions {
            while !completions.isEmpty {
                guard let current = completions.dequeue() else {
                    return
                }
                current(result)
            }
        }
    }

    private func startPoll(mode: AutoPollingMode) {
        pollTimer = DispatchSource.makeTimerSource()
        pollTimer?.schedule(deadline: .now(), repeating: .seconds(mode.autoPollIntervalInSeconds))
        let ageThreshold = Int(Double(mode.autoPollIntervalInSeconds) * 0.8)
        pollTimer?.setEventHandler(handler: { [weak self] in
            guard let this = self else {
                return
            }
            this.log.debug(message: "Polling for config.json changes.")
            this.fetchIfOlder(time: Date().subtract(seconds: ageThreshold)!) { _ in
                // we don't have to do anything with the result in the timer ticks.
            }
        })
        pollTimer?.resume()
    }

    private func writeCache(entry: ConfigEntry) {
        guard let cache = cache else {
            return
        }
        do {
            let jsonMap = entry.toJsonMap()
            let json = try JSONSerialization.data(withJSONObject: jsonMap, options: [])
            guard let jsonString = String(data: json, encoding: .utf8) else {
                log.error(message: "An error occurred during the cache write: Could not convert the JSON object to string.")
                return
            }
            cachedJsonString = jsonString
            try cache.write(for: cacheKey, value: jsonString)
        } catch {
            log.error(message: String(format: "An error occurred during the cache write: %@", error.localizedDescription))
        }
    }

    private func readCache() -> ConfigEntry {
        guard let cache = cache else {
            return .empty
        }
        do {
            let json = try cache.read(for: cacheKey)
            if json.isEmpty || json == cachedJsonString {
                return .empty
            }
            guard let data = json.data(using: .utf8) else {
                log.error(message: "An error occurred during the cache read: Decode to utf8 data failed.")
                return .empty
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                log.error(message: "An error occurred during the cache read: Convert to [String: Any] map failed.")
                return .empty
            }
            cachedJsonString = json
            return .fromJson(json: jsonObject)
        } catch {
            log.error(message: String(format: "An error occurred during the cache read: %@", error.localizedDescription))
            return .empty
        }
    }
}
