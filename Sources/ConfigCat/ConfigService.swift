import Foundation

class SettingResult {
    let settings: [String: Setting]
    let fetchTime: Date

    init(settings: [String: Setting], fetchTime: Date) {
        self.settings = settings
        self.fetchTime = fetchTime
    }

    var isEmpty: Bool {
        get {
            self === SettingResult.empty
        }
    }

    static let empty = SettingResult(settings: [:], fetchTime: .distantPast)
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
    case failure(String, ConfigEntry)
}

class ConfigService {
    private let log: Logger
    private let fetcher: ConfigFetcher
    private let mutex: Mutex = Mutex(recursive: true)
    private let cache: ConfigCache?
    private let pollingMode: PollingMode
    private let hooks: Hooks
    private let cacheKey: String
    private var initialized: Bool = false
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
        cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)

        if let autoPoll = pollingMode as? AutoPollingMode, !offline {

            startPoll(mode: autoPoll)

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
                    this.log.warning(eventId: 4200, message: String(format: "`maxInitWaitTimeInSeconds` for the very first fetch reached (%ds). Returning cached config.", autoPoll.maxInitWaitTimeInSeconds))
                    this.initialized = true
                    hooks.invokeOnReady(state: this.determineReadyState())
                    this.callCompletions(result: .success(this.cachedEntry))
                    this.completions = nil
                }
            })
            initTimer?.resume()
        } else {
            // Sync up with cache before reporting ready state
            cachedEntry = readCache()
            setInitialized()
        }
    }

    func close() {
        mutex.lock()
        defer { mutex.unlock() }
        callCompletions(result: .success(cachedEntry))
        completions = nil
        pollTimer?.cancel()
        initTimer?.cancel()
    }

    func settings(completion: @escaping (SettingResult) -> Void) {
        switch pollingMode {
        case let lazyMode as LazyLoadingMode:
            fetchIfOlder(time: Date().subtract(seconds: lazyMode.cacheRefreshIntervalInSeconds)!) { result in
                switch result {
                case .success(let entry): completion(!entry.isEmpty
                    ? SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime)
                    : SettingResult.empty)
                case .failure(_, let entry): completion(!entry.isEmpty
                    ? SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime)
                    : SettingResult.empty)
                }
            }
        default:
            fetchIfOlder(time: .distantPast, preferCache: true) { result in
                switch result {
                case .success(let entry): completion(!entry.isEmpty
                    ? SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime)
                    : SettingResult.empty)
                case .failure(_, let entry): completion(!entry.isEmpty
                    ? SettingResult(settings: entry.config.entries, fetchTime: entry.fetchTime)
                    : SettingResult.empty)
                }
            }
        }
    }

    func refresh(completion: @escaping (RefreshResult) -> Void) {
        if isOffline {
            let offlineWarning = "Client is in offline mode, it cannot initiate HTTP calls."
            log.warning(eventId: 3200, message: offlineWarning)
            completion(RefreshResult(success: false, error: offlineWarning))
            return
        }

        fetchIfOlder(time: .distantFuture) { result in
            switch result {
            case .success: completion(RefreshResult(success: true))
            case .failure(let error, _): completion(RefreshResult(success: false, error: error))
            }
        }
    }

    func setOnline() {
        mutex.lock()
        defer { mutex.unlock() }
        if !offline { return }
        offline = false
        if let autoPoll = pollingMode as? AutoPollingMode {
            startPoll(mode: autoPoll)
        }
        log.info(eventId: 5200, message: "Switched to ONLINE mode.")
    }

    func setOffline() {
        mutex.lock()
        defer { mutex.unlock() }
        if offline { return }
        offline = true
        pollTimer?.cancel()
        pollTimer = nil
        log.info(eventId: 5200, message: "Switched to OFFLINE mode.")
    }

    var isOffline: Bool {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return offline
        }
    }
    
    func onReady(completion: @escaping (ClientReadyState) -> Void) {
        mutex.lock()
        defer { mutex.unlock() }
        if initialized {
            completion(determineReadyState())
        } else {
            hooks.addOnReady(handler: completion)
        }
    }
    
    var inMemory: ConfigEntry {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return cachedEntry
        }
    }

    private func fetchIfOlder(time: Date, preferCache: Bool = false, completion: @escaping (FetchResult) -> Void) {
        mutex.lock()
        defer { mutex.unlock() }
        // Sync up with the cache and use it when it's not expired.
        if cachedEntry.isEmpty || cachedEntry.fetchTime > time {
            let entry = readCache()
            if !entry.isEmpty && entry != cachedEntry {
                cachedEntry = entry
                hooks.invokeOnConfigChanged(settings: entry.config.entries)
            }
            // Cache isn't expired
            if cachedEntry.fetchTime > time {
                setInitialized()
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
            completion(.success(cachedEntry))
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
        defer { mutex.unlock() }

        switch response {
        case .fetched(let entry):
            cachedEntry = entry
            writeCache(entry: entry)
            hooks.invokeOnConfigChanged(settings: entry.config.entries)
            callCompletions(result: .success(entry))
        case .notModified:
            cachedEntry = cachedEntry.withFetchTime(time: Date())
            writeCache(entry: cachedEntry)
            callCompletions(result: .success(cachedEntry))
        case .failure(let error, let isTransient):
            if !isTransient && !cachedEntry.isEmpty {
                cachedEntry = cachedEntry.withFetchTime(time: Date())
                writeCache(entry: cachedEntry)
            }
            callCompletions(result: .failure(error, cachedEntry))
        }
        completions = nil
        setInitialized()
    }

    private func setInitialized() {
        if !initialized {
            initialized = true
            hooks.invokeOnReady(state: determineReadyState())
        }
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
            let jsonString = entry.serialize()
            cachedJsonString = jsonString
            try cache.write(for: cacheKey, value: jsonString)
        } catch {
            log.error(eventId: 2201, message: String(format: "Error occurred while writing the cache. %@", error.localizedDescription))
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
            let cached = ConfigEntry.fromCached(cached: json)
            switch cached {
            case .success(let entry):
                cachedJsonString = json
                return entry
            case .failure(let error):
                log.error(eventId: 2200, message: String(format: "Error occurred while reading the cache. %@", error.localizedDescription))
                return .empty
            }
        } catch {
            log.error(eventId: 2200, message: String(format: "Error occurred while reading the cache. %@", error.localizedDescription))
            return .empty
        }
    }
    
    private func determineReadyState() -> ClientReadyState {
        if cachedEntry.isEmpty {
            return .noFlagData
        }
        
        switch pollingMode {
        case let lazyMode as LazyLoadingMode:
            if cachedEntry.isExpired(seconds: lazyMode.cacheRefreshIntervalInSeconds) {
                return .hasCachedFlagDataOnly
            }
        case let autoMode as AutoPollingMode:
            if cachedEntry.isExpired(seconds: autoMode.autoPollIntervalInSeconds) {
                return .hasCachedFlagDataOnly
            }
        default: // manual polling
            return .hasCachedFlagDataOnly
        }
        
        return .hasUpToDateFlagData
    }
}
