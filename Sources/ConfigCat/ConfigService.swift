import Foundation

class SettingsResult {
    let settings: [String: Setting]
    let fetchTime: Date
    let isEmpty: Bool

    init(settings: [String: Setting], fetchTime: Date, isEmpty: Bool = false) {
        self.settings = settings
        self.fetchTime = fetchTime
        self.isEmpty = isEmpty
    }

    static var empty: SettingsResult { SettingsResult(settings: [:], fetchTime: .distantPast, isEmpty: true) }
}

class InMemoryResult {
    let entry: ConfigEntry
    let cacheState: ClientCacheState

    init(entry: ConfigEntry, cacheState: ClientCacheState) {
        self.entry = entry
        self.cacheState = cacheState
    }
}

/// Specifies the possible evaluation error codes.
@objc public enum RefreshErrorCode: Int, Sendable {
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

public final class RefreshResult: NSObject, Sendable {
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
    private var started: Bool = false
    private var initialized: Bool = false
    private var offline: Bool = false
    private var closed: Bool = false
    private var cachedEntry: ConfigEntry = .empty
    private var completions: MutableQueue<(FetchResult) -> Void>?
    private var readyWaiters: [(ClientCacheState) -> ()] = []
    private var readyState: ClientCacheState?
    private var fetchInProgress = false
    private var pollTimer: DispatchSourceTimer? = nil
    private var initTimer: DispatchSourceTimer? = nil

    init(
        snapshotBuilder: SnapshotBuilderProtocol, log: InternalLogger, fetcher: ConfigFetcher,
        cache: ConfigCache?, pollingMode: PollingMode, hooks: Hooks, sdkKey: String, offline: Bool
    ) {
        self.snapshotBuilder = snapshotBuilder
        self.log = log
        self.fetcher = fetcher
        self.cache = cache
        self.pollingMode = pollingMode
        self.hooks = hooks
        self.offline = offline
        cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
    }

    func start() {
        if let autoPoll = pollingMode as? AutoPollingMode {
            mutex.withLock {
                if closed || started { return }

                started = true
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
                    // Max wait time expired without result, notify subscribers with the cached config.
                    let ready = this.mutex.withLock { () -> (InMemoryResult, [(ConfigCatClientSnapshot) -> Void], MutableQueue<(FetchResult) -> Void>?, [(ClientCacheState) -> ()])? in
                        guard !this.initialized && !this.closed else { return nil }
                        this.initialized = true
                        let result = this.produceInMemoryResult(entry: this.cachedEntry)
                        this.readyState = result.cacheState
                        let readyCallbacks = this.hooks.snapshotReadyCallbacks()
                        return (result, readyCallbacks, this.takeAndClearCompletions(), this.takeAndClearReadyWaiters())
                    }
                    if let (result, readyCallbacks, pendingCompletions, readyWaiters) = ready {
                        this.unblockReadyWaiters(waiters: readyWaiters, cacheState: result.cacheState)
                        this.log.warning(
                            eventId: 4200,
                            message: String(
                                format:
                                    "`maxInitWaitTimeInSeconds` for the very first fetch reached (%ds). Returning cached config.",
                                autoPoll.maxInitWaitTimeInSeconds))
                        this.hooks.invokeReadyCallbacks(callbacks: readyCallbacks, snapshotBuilder: this.snapshotBuilder, inMemoryResult: result)
                        this.callCompletions(pendingCompletions, result: .success(result.entry))
                    }
                })
                initTimer?.resume()
            }
        } else {
            let shouldSync = mutex.withLock {
                if closed || started { return false }
                started = true
                return true
            }
            if shouldSync {
                fetchIfOlder(threshold: Date.distantPast, preferCache: true) { _ in }
            }
        }
    }

    func close() {
        let entryAndCompletions = mutex.withLock { () -> (ConfigEntry, ClientCacheState, MutableQueue<(FetchResult) -> Void>?, [((ClientCacheState) -> ())])? in
            guard !closed else {
                return nil
            }
            closed = true
            let state = readyState ?? determineReadyState(entry: cachedEntry)
            if readyState == nil {
                readyState = state
            }
            pollTimer?.cancel()
            initTimer?.cancel()
            return (cachedEntry, state, takeAndClearCompletions(), takeAndClearReadyWaiters())
        }
        if let (entry, readyState, pendingCompletions, readyWaiters) = entryAndCompletions {
            unblockReadyWaiters(waiters: readyWaiters, cacheState: readyState)
            callCompletions(pendingCompletions, result: .success(entry))
        }
    }

    func settings(completion: @escaping (SettingsResult) -> Void) {
        var threshold = Date.distantPast
        var preferCache = isInitialized
        if let lazyMode = pollingMode as? LazyLoadingMode {
            threshold = Date().addingTimeInterval(-TimeInterval(lazyMode.cacheRefreshIntervalInSeconds))
            preferCache = false
        } else if let autoPoll = pollingMode as? AutoPollingMode, !isInitialized {
            threshold = Date().addingTimeInterval(-TimeInterval(autoPoll.autoPollIntervalInSeconds))
        } else if pollingMode is ManualPollingMode {
            preferCache = true
        }

        fetchIfOlder(threshold: threshold, preferCache: preferCache) { result in
            switch result {
            case .success(let entry):
                completion(
                    !entry.isEmpty
                        ? SettingsResult(
                            settings: entry.config.settings, fetchTime: entry.fetchTime)
                        : .empty)
            case .failure(_, _, let entry):
                completion(
                    !entry.isEmpty
                        ? SettingsResult(
                            settings: entry.config.settings, fetchTime: entry.fetchTime)
                        : .empty)
            }
        }
    }

    func refresh(completion: @escaping (RefreshResult) -> Void) {
        if isOffline && cache == nil {
            let offlineWarning = "Client is in offline mode, it cannot initiate HTTP calls."
            log.warning(eventId: 3200, message: offlineWarning)
            completion(
                RefreshResult(success: false, errorCode: .offlineClient, error: offlineWarning))
            return
        }

        fetchIfOlder(threshold: .distantFuture) { result in
            switch result {
            case .success: completion(RefreshResult(success: true, errorCode: .none))
            case .failure(let error, let errorCode, _):
                completion(RefreshResult(success: false, errorCode: errorCode, error: error))
            }
        }
    }

    func setOnline() {
        let stateChanged = mutex.withLock {
            if closed || !offline {
                return false
            }
            offline = false
            if !started {
                return true
            }
            pollTimer?.cancel()
            pollTimer = nil
            if let autoPoll = pollingMode as? AutoPollingMode {
                startPoll(mode: autoPoll)
            }
            return true
        }
        if stateChanged {
            log.info(eventId: 5200, message: "Switched to ONLINE mode.")
        }
    }

    func setOffline() {
        let stateChanged = mutex.withLock {
            if closed || offline {
                return false
            }
            offline = true
            return true
        }
        if stateChanged {
            log.info(eventId: 5200, message: "Switched to OFFLINE mode.")
        }
    }

    func waitForReady(handler: @escaping (ClientCacheState) -> ()) {
        let state: ClientCacheState? = mutex.withLock {
            if initialized || closed {
                return readyState
            }
            readyWaiters.append(handler)
            return nil
        }
        if let state = state {
            handler(state)
        }
    }

    var isOffline: Bool {
        return mutex.withLock {
            offline
        }
    }

    var inMemory: InMemoryResult {
        return mutex.withLock {
            return produceInMemoryResult(entry: cachedEntry)
        }  
    }

    private var isInitialized: Bool {
        return mutex.withLock {
            initialized
        }
    }

    private func fetchIfOlder(
        threshold: Date, preferCache: Bool = false, completion: @escaping (FetchResult) -> Void
    ) {
        let entry = readCache()
        var configChanged = false
        var expired = false
        var clientOffline = false
        let (currentEntry, isClosed) = mutex.withLock {
            guard !closed else {
                return (cachedEntry, true)
            }

            if !entry.isEmpty, entry != cachedEntry, cachedEntry.isEmpty || entry.fetchTime > cachedEntry.fetchTime {
                cachedEntry = entry
                configChanged = true
            }
            expired = cachedEntry.fetchTime <= threshold
            clientOffline = offline
            return (cachedEntry, false)
        }

        if isClosed {
            completion(.success(currentEntry))
            return
        }

        if configChanged {
            reportConfigChanged(entry: currentEntry)
        }

        if !expired || clientOffline || preferCache {
            setInitializedAndReportReady(entry: currentEntry)
            completion(.success(currentEntry))
            return
        }

        if shouldInitiateFetchOrSubscribeCompletion(completion: completion) {
            let etag = currentEntry.isEmpty ? "" : currentEntry.eTag
            fetcher.fetch(eTag: etag) { response in
                self.processResponse(response: response)
            }
        }
    }

    private func shouldInitiateFetchOrSubscribeCompletion(
        completion: @escaping (FetchResult) -> Void
    ) -> Bool {
        let (closedEntry, shouldInitiate): (ConfigEntry?, Bool) = mutex.withLock {
            guard !closed else {
                return (cachedEntry, false)
            }
            if completions == nil {
                completions = MutableQueue()
            }
            completions?.enqueue(item: completion)
            guard !fetchInProgress else { return (nil, false) }
            fetchInProgress = true
            return (nil, true)
        }
        if let entry = closedEntry {
            completion(.success(entry))
        }
        return shouldInitiate
    }

    private func processResponse(response: FetchResponse) {
        var completionResult: FetchResult?
        var pendingCompletions: MutableQueue<(FetchResult) -> Void>?
        var configChanged = false
        var writeEntryToCache = true
        let currentEntry: ConfigEntry? = mutex.withLock {
            guard !closed else { return nil }

            switch response {
            case .fetched(let entry):
                cachedEntry = entry
                configChanged = true
                completionResult = .success(entry)
            case .notModified:
                cachedEntry = cachedEntry.withFetchTime(time: Date())
                completionResult = .success(cachedEntry)
            case .failure(let error, let errorCode, let isTransient):
                if !isTransient && !cachedEntry.isEmpty {
                    cachedEntry = cachedEntry.withFetchTime(time: Date())
                } else {
                    writeEntryToCache = false
                }
                completionResult = .failure(error, errorCode, cachedEntry)
                
            }
            fetchInProgress = false
            pendingCompletions = takeAndClearCompletions()
            return cachedEntry
        }
        if let entry = currentEntry {
            if writeEntryToCache {
                writeCache(entry: entry)
            }
            setInitializedAndReportReady(entry: entry)
            if configChanged {
                reportConfigChanged(entry: entry)
            }
            if let result = completionResult {
                callCompletions(pendingCompletions, result: result)
            }
        }
    }

    private func setInitializedAndReportReady(entry: ConfigEntry) {
        let ready = mutex.withLock { () -> (InMemoryResult, [(ConfigCatClientSnapshot) -> ()], [(ClientCacheState) -> ()])? in
            guard !initialized && !closed else { return nil }
            initialized = true
            let result = produceInMemoryResult(entry: entry)
            readyState = result.cacheState
            let readyCallbacks = hooks.snapshotReadyCallbacks()
            return (result, readyCallbacks, takeAndClearReadyWaiters())
        }
        if let (result, readyCallbacks, readyWaiters) = ready {
            unblockReadyWaiters(waiters: readyWaiters, cacheState: result.cacheState)
            hooks.invokeReadyCallbacks(callbacks: readyCallbacks, snapshotBuilder: snapshotBuilder, inMemoryResult: result)
        }
    }

    private func reportConfigChanged(entry: ConfigEntry) {
        hooks.invokeOnConfigChanged(snapshotBuilder: snapshotBuilder, inMemoryResult: produceInMemoryResult(entry: entry))
    }

    private func takeAndClearCompletions() -> MutableQueue<(FetchResult) -> Void>? {
        let pending = completions
        completions = nil
        return pending
    }

    private func takeAndClearReadyWaiters() -> [(ClientCacheState) -> ()] {
        let waiters = readyWaiters
        readyWaiters = []
        return waiters
    }

    private func callCompletions(_ pending: MutableQueue<(FetchResult) -> Void>?, result: FetchResult) {
        if let completions = pending {
            while !completions.isEmpty {
                guard let current = completions.dequeue() else {
                    return
                }
                current(result)
            }
        }
    }

    private func unblockReadyWaiters(waiters: [(ClientCacheState) -> ()], cacheState: ClientCacheState) {
        for waiter in waiters {
            waiter(cacheState)
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
            this.fetchIfOlder(threshold: Date().addingTimeInterval(-TimeInterval(ageThreshold))) { _ in
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
            try cache.write(for: cacheKey, value: entry.cacheString)
        } catch {
            log.error(
                eventId: 2201,
                message: String(
                    format: "Error occurred while writing the cache. %@", error.localizedDescription
                ))
        }
    }

    private func readCache() -> ConfigEntry {
        guard let cache = cache else {
            return .empty
        }
        let entryAtReadStart = mutex.withLock {
            cachedEntry
        }
        do {
            let json = try cache.read(for: cacheKey)
            if json.isEmpty || json == entryAtReadStart.cacheString {
                return .empty
            }
            let cached = ConfigEntry.fromCached(cached: json)
            switch cached {
            case .success(let entry):
                return entry
            case .failure(let error):
                log.error(
                    eventId: 2200,
                    message: String(
                        format: "Error occurred while reading the cache. %@",
                        error.localizedDescription))
                return .empty
            }
        } catch {
            log.error(
                eventId: 2200,
                message: String(
                    format: "Error occurred while reading the cache. %@", error.localizedDescription
                ))
            return .empty
        }
    }

    private func produceInMemoryResult(entry: ConfigEntry) -> InMemoryResult {
        return InMemoryResult(entry: entry, cacheState: determineReadyState(entry: entry))
    }

    private func determineReadyState(entry: ConfigEntry) -> ClientCacheState {
        if entry.isEmpty {
            return .noFlagData
        }

        switch pollingMode {
        case let lazyMode as LazyLoadingMode:
            if entry.isExpired(seconds: lazyMode.cacheRefreshIntervalInSeconds) {
                return .hasCachedFlagDataOnly
            }
        case let autoMode as AutoPollingMode:
            if entry.isExpired(seconds: autoMode.autoPollIntervalInSeconds) {
                return .hasCachedFlagDataOnly
            }
        default:  // manual polling
            return .hasCachedFlagDataOnly
        }

        return .hasUpToDateFlagData
    }
}
