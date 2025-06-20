import Foundation

class SettingsResult {
    let settings: [String: Setting]
    let fetchTime: Date

    init(settings: [String: Setting], fetchTime: Date) {
        self.settings = settings
        self.fetchTime = fetchTime
    }

    var isEmpty: Bool {
        get {
            self === SettingsResult.empty
        }
    }

    static let empty = SettingsResult(settings: [:], fetchTime: .distantPast)
}

class InMemoryResult {
    let entry: ConfigEntry
    let cacheState: ClientCacheState
    
    init(entry: ConfigEntry, cacheState: ClientCacheState) {
        self.entry = entry
        self.cacheState = cacheState
    }
}

/**
 Specifies the possible evaluation error codes.
 */
@objc public enum RefreshErrorCode: Int {
    /** An unexpected error occurred during the refresh operation. */
    case unexpectedError = -1
    /** No error occurred (the refresh operation was successful). */
    case none = 0
    /**
     The refresh operation failed because the client is configured to use the `OverrideBehaviour.localOnly` override behavior,
     which prevents synchronization with the external cache and making HTTP requests.
     */
    case localOnlyClient = 1
    /** The refresh operation failed because the client is in offline mode, it cannot initiate HTTP requests. */
    case offlineClient = 3200
    /** The refresh operation failed because a HTTP response indicating an invalid SDK Key was received (403 Forbidden or 404 Not Found). */
    case invalidSdkKey = 1100
    /** The refresh operation failed because an invalid HTTP response was received (unexpected HTTP status code). */
    case unexpectedHttpResponse = 1101
    /** The refresh operation failed because the HTTP request timed out. */
    case httpRequestTimeout = 1102
    /** The refresh operation failed because the HTTP request failed (most likely, due to a local network issue). */
    case httpRequestFailure = 1103
    /** The refresh operation failed because an invalid HTTP response was received (200 OK with an invalid content). */
    case invalidHttpResponseContent = 1105
}

public final class RefreshResult: NSObject {
    @objc public let success: Bool
    @objc public let error: String?
    @objc public let errorCode: RefreshErrorCode

    init(success: Bool, errorCode: RefreshErrorCode, error: String? = nil) {
        self.success = success
        self.error = error
        self.errorCode = errorCode
    }
}

enum FetchResult {
    case success(ConfigEntry)
    case failure(String, RefreshErrorCode, ConfigEntry)
}

class ConfigService {
    private let snapshotBuilder: SnapshotBuilderProtocol
    private let log: InternalLogger
    private let fetcher: ConfigFetcher
    private let mutex: Mutex = Mutex(recursive: true)
    private let cache: ConfigCache?
    private let pollingMode: PollingMode
    private let hooks: Hooks
    private let cacheKey: String
    @Synced private var initialized: Bool = false
    private var offline: Bool = false
    private var completions: MutableQueue<(FetchResult) -> Void>?
    private var cachedEntry: ConfigEntry = .empty
    private var cachedJsonString: String = ""
    private var pollTimer: DispatchSourceTimer? = nil
    private var initTimer: DispatchSourceTimer? = nil

    init(snapshotBuilder: SnapshotBuilderProtocol, log: InternalLogger, fetcher: ConfigFetcher, cache: ConfigCache?, pollingMode: PollingMode, hooks: Hooks, sdkKey: String, offline: Bool) {
        self.snapshotBuilder = snapshotBuilder
        self.log = log
        self.fetcher = fetcher
        self.cache = cache
        self.pollingMode = pollingMode
        self.hooks = hooks
        self.offline = offline
        cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)

        if let autoPoll = pollingMode as? AutoPollingMode {

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
                if this._initialized.testAndSet(expect: false, new: true) {
                    this.log.warning(eventId: 4200, message: String(format: "`maxInitWaitTimeInSeconds` for the very first fetch reached (%ds). Returning cached config.", autoPoll.maxInitWaitTimeInSeconds))
                    hooks.invokeOnReady(snapshotBuilder: snapshotBuilder, inMemoryResult: this.inMemory)
                    this.callCompletions(result: .success(this.cachedEntry))
                    this.completions = nil
                }
            })
            initTimer?.resume()
        } else {
            // Sync up with cache before reporting ready state
            let entry = readCache()
            if !entry.isEmpty && entry != cachedEntry {
                cachedEntry = entry
                hooks.invokeOnConfigChanged(snapshotBuilder: snapshotBuilder, inMemoryResult: inMemory)
            }
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

    func settings(completion: @escaping (SettingsResult) -> Void) {
        var threshold = Date.distantPast
        var preferCache = initialized
        if let lazyMode = pollingMode as? LazyLoadingMode {
            threshold = Date().subtract(seconds: lazyMode.cacheRefreshIntervalInSeconds)!
            preferCache = false
        }
        else if let autoPoll = pollingMode as? AutoPollingMode, !initialized {
            threshold = Date().subtract(seconds: autoPoll.autoPollIntervalInSeconds)!
        }
        
        fetchIfOlder(threshold: threshold, preferCache: preferCache) { result in
            switch result {
            case .success(let entry): completion(!entry.isEmpty
                                                 ? SettingsResult(settings: entry.config.settings, fetchTime: entry.fetchTime)
                                                 : .empty)
            case .failure(_, _, let entry): completion(!entry.isEmpty
                                                    ? SettingsResult(settings: entry.config.settings, fetchTime: entry.fetchTime)
                                                    : .empty)
            }
        }
    }

    func refresh(completion: @escaping (RefreshResult) -> Void) {
        if isOffline && cache == nil {
            let offlineWarning = "Client is in offline mode, it cannot initiate HTTP calls."
            log.warning(eventId: 3200, message: offlineWarning)
            completion(RefreshResult(success: false, errorCode: .offlineClient, error: offlineWarning))
            return
        }

        fetchIfOlder(threshold: .distantFuture) { result in
            switch result {
            case .success: completion(RefreshResult(success: true, errorCode: .none))
            case .failure(let error, let errorCode, _): completion(RefreshResult(success: false, errorCode: errorCode, error: error))
            }
        }
    }

    func setOnline() {
        mutex.lock()
        defer { mutex.unlock() }
        if !offline { return }
        offline = false
        pollTimer?.cancel()
        pollTimer = nil
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
        log.info(eventId: 5200, message: "Switched to OFFLINE mode.")
    }

    var isOffline: Bool {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return offline
        }
    }

    var inMemory: InMemoryResult {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return InMemoryResult(entry: cachedEntry, cacheState: determineReadyState())
        }
    }

    private func fetchIfOlder(threshold: Date, preferCache: Bool = false, completion: @escaping (FetchResult) -> Void) {
        mutex.lock()
        defer { mutex.unlock() }
        // Sync up with the cache and use it when it's not expired.
        let entry = readCache()
        if !entry.isEmpty && entry != cachedEntry {
            cachedEntry = entry
            hooks.invokeOnConfigChanged(snapshotBuilder: snapshotBuilder, inMemoryResult: inMemory)
        }
        // Cache isn't expired
        if cachedEntry.fetchTime > threshold {
            setInitialized()
            completion(.success(cachedEntry))
            return
        }
        // If we are in offline mode or the caller prefers cached values, do not initiate fetch.
        if offline || preferCache {
            setInitialized()
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
            hooks.invokeOnConfigChanged(snapshotBuilder: snapshotBuilder, inMemoryResult: inMemory)
            callCompletions(result: .success(entry))
        case .notModified:
            cachedEntry = cachedEntry.withFetchTime(time: Date())
            writeCache(entry: cachedEntry)
            callCompletions(result: .success(cachedEntry))
        case .failure(let error, let errorCode, let isTransient):
            if !isTransient && !cachedEntry.isEmpty {
                cachedEntry = cachedEntry.withFetchTime(time: Date())
                writeCache(entry: cachedEntry)
            }
            callCompletions(result: .failure(error, errorCode, cachedEntry))
        }
        completions = nil
        setInitialized()
    }

    private func setInitialized() {
        if _initialized.testAndSet(expect: false, new: true) {
            hooks.invokeOnReady(snapshotBuilder: snapshotBuilder, inMemoryResult: inMemory)
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
            this.fetchIfOlder(threshold: Date().subtract(seconds: ageThreshold)!) { _ in
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
    
    private func determineReadyState() -> ClientCacheState {
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
