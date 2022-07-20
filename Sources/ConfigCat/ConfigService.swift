import Foundation

class ConfigService {
    fileprivate let log: Logger
    fileprivate let fetcher: ConfigFetcher
    fileprivate let mutex: Mutex = Mutex(recursive: true)
    fileprivate let cache: ConfigCache?
    fileprivate let pollingMode: PollingMode
    fileprivate let cacheKey: String
    fileprivate let initialized: Synced<Bool>
    fileprivate var completions: MutableQueue<(Config) -> Void>?
    fileprivate var cachedEntry: ConfigEntry = .empty
    fileprivate var polltimer: DispatchSourceTimer? = nil
    fileprivate var initTimer: DispatchSourceTimer? = nil

    init(log: Logger, fetcher: ConfigFetcher, cache: ConfigCache?, pollingMode: PollingMode, sdkKey: String) {
        self.log = log
        self.fetcher = fetcher
        self.cache = cache
        self.pollingMode = pollingMode
        let keyToHash = "swift_" + sdkKey + "_" + Constants.configJsonName
        cacheKey = String(keyToHash.sha1hex ?? keyToHash)

        if let autoPoll = pollingMode as? AutoPollingMode {
            initialized = Synced<Bool>(initValue: false)
            polltimer = DispatchSource.makeTimerSource()
            polltimer?.schedule(deadline: .now(), repeating: .seconds(autoPoll.autoPollIntervalInSeconds))
            polltimer?.setEventHandler(handler: { [weak self] in
                guard let `self` = self else {
                    return
                }
                self.fetchIfOlder(time: Date.distantFuture) { _ in }
            })
            polltimer?.resume()

            // Waiting for the client initialization.
            // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while the config is not ready
            // the default value will be returned.
            initTimer = DispatchSource.makeTimerSource()
            initTimer?.schedule(deadline: .now() + .seconds(autoPoll.maxInitWaitTimeInSeconds))
            initTimer?.setEventHandler(handler: { [weak self] in
                guard let `self` = self else {
                    return
                }
                if !self.initialized.getAndSet(new: true) {
                    self.processResponse(response: .failure)
                }
            })
            initTimer?.resume()
        } else {
            initialized = Synced<Bool>(initValue: true)
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
            fetchIfOlder(time: Date.distantPast) { config in
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
        if preferCache && initialized.get() {
            completion(cachedEntry.config)
            return
        }
        // An ongoing fetch is running, save the callback for later notification.
        if completions != nil {
            completions?.enqueue(item: completion)
            return
        }
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
        switch response {
        case .fetched(let entry) where entry != cachedEntry:
            _ = initialized.testAndSet(expect: false, new: true)
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
