import Foundation

class ConfigService {
    private let log: Logger
    private let fetcher: ConfigFetcher
    private let mutex: Mutex = Mutex(recursive: true)
    private let cache: ConfigCache?
    private let pollingMode: PollingMode
    private let cacheKey: String
    private var initialized: Bool
    private var completions: MutableQueue<(Config) -> Void>?
    private var cachedEntry: ConfigEntry = .empty
    private var polltimer: DispatchSourceTimer? = nil
    private var initTimer: DispatchSourceTimer? = nil

    init(log: Logger, fetcher: ConfigFetcher, cache: ConfigCache?, pollingMode: PollingMode, sdkKey: String) {
        self.log = log
        self.fetcher = fetcher
        self.cache = cache
        self.pollingMode = pollingMode
        let keyToHash = "swift_" + sdkKey + "_" + Constants.configJsonName
        cacheKey = String(keyToHash.sha1hex ?? keyToHash)

        if let autoPoll = pollingMode as? AutoPollingMode {
            initialized = false
            polltimer = DispatchSource.makeTimerSource()
            polltimer?.schedule(deadline: .now(), repeating: .seconds(autoPoll.autoPollIntervalInSeconds))
            polltimer?.setEventHandler(handler: { [weak self] in
                guard let this = self else {
                    return
                }
                this.fetchIfOlder(time: Date.distantFuture) { _ in
                    // we don't have to do anything with the result in the timer ticks.
                }
            })
            polltimer?.resume()

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
                defer { this.mutex.unlock() }
                // Max wait time expired without result, notify subscribers with the cached config.
                if !this.initialized {
                    this.initialized = true
                    this.callCompletions(config: this.cachedEntry.config)
                    this.completions = nil
                }
            })
            initTimer?.resume()
        } else {
            initialized = true
        }
    }

    deinit {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        callCompletions(config: cachedEntry.config)
        completions = nil
        polltimer?.cancel()
        initTimer?.cancel()
    }

    func settings(completion: @escaping ([String: Any]) -> Void) {
        switch pollingMode {
        case let lazy as LazyLoadingMode:
            fetchIfOlder(time: Date().subtract(seconds: lazy.cacheRefreshIntervalInSeconds)!) { config in
                completion(config.entries)
            }
        default:
            fetchIfOlder(time: Date.distantPast, preferCache: true) { config in
                completion(config.entries)
            }
        }
    }

    func refresh(completion: @escaping () -> Void) {
        fetchIfOlder(time: Date.distantFuture) { _ in
            completion()
        }
    }

    private func fetchIfOlder(time: Date, preferCache: Bool = false, completion: @escaping (Config) -> Void) {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        // Sync up with the cache and use it when it's not expired.
        if cachedEntry.isEmpty || cachedEntry.fetchTime > time {
            let json = readConfigCache()
            if !json.isEmpty && json != cachedEntry.jsonString {
                let parseResult = json.parseConfigFromJson()
                switch parseResult {
                case .success(let config):
                    cachedEntry = ConfigEntry(jsonString: json, config: config, eTag: "")
                case .failure(let error):
                    log.error(message: "An error occurred during JSON deserialization. %@", error.localizedDescription)
                }
            }
            if cachedEntry.fetchTime > time {
                completion(cachedEntry.config)
                return
            }
        }
        // Use cache anyway (get calls on auto & manual poll must not initiate fetch).
        // The initialized check ensures that we subscribe for the ongoing fetch during the
        // max init wait time window in case of auto poll.
        if preferCache && initialized {
            completion(cachedEntry.config)
            return
        }
        // There's an ongoing fetch running, save the callback to call it later when the ongoing fetch finishes.
        if completions != nil {
            completions?.enqueue(item: completion)
            return
        }
        // No fetch is running, initiate a new one.
        completions = MutableQueue<(Config) -> Void>()
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
        initialized = true
        switch response {
        case .fetched(let entry) where entry != cachedEntry:
            cachedEntry = entry
            writeConfigCache(json: entry.jsonString)
            if let auto = pollingMode as? AutoPollingMode {
                auto.onConfigChanged?()
            }
            callCompletions(config: entry.config)
        case .notModified:
            cachedEntry = cachedEntry.withFetchTime(time: Date())
            callCompletions(config: cachedEntry.config)
        default:
            callCompletions(config: cachedEntry.config)
        }
        completions = nil
    }

    private func callCompletions(config: Config) {
        if let completions = completions {
            while !completions.isEmpty {
                guard let current = completions.dequeue() else {
                    return
                }
                current(config)
            }
        }
    }

    private func writeConfigCache(json: String) {
        guard let cache = cache else {
            return
        }
        do {
            try cache.write(for: cacheKey, value: json)
        } catch {
            log.error(message: "An error occurred during the cache write: %@", error.localizedDescription)
        }
    }

    private func readConfigCache() -> String {
        guard let cache = cache else {
            return ""
        }
        do {
            return try cache.read(for: cacheKey)
        } catch {
            log.error(message: "An error occurred during the cache read: %@", error.localizedDescription)
            return ""
        }
    }
}
