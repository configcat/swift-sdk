import Foundation

final class SettingsResult: Sendable {
    let settings: [String: Setting]
    let fetchTime: Date
    let isEmpty: Bool

    init(settings: [String: Setting], fetchTime: Date, isEmpty: Bool = false) {
        self.settings = settings
        self.fetchTime = fetchTime
        self.isEmpty = isEmpty
    }

    func withOverrides(_ overrides: [String: Setting], preferOverrides: Bool) -> SettingsResult {
        if isEmpty && overrides.isEmpty {
            return .empty
        }
        return SettingsResult(
            settings: settings.merging(overrides) { current, overrideValue in
                preferOverrides ? overrideValue : current
            },
            fetchTime: fetchTime
        )
    }

    static var empty: SettingsResult { SettingsResult(settings: [:], fetchTime: .distantPast, isEmpty: true) }
}

final class InMemoryResult: Sendable {
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

enum FetchResult: Sendable {
    case success(ConfigEntry)
    case failure(String, RefreshErrorCode, ConfigEntry)
}

final class ConfigService: Sendable {
    private enum FetchDecision {
        case closed(ConfigEntry)
        case useCache(ConfigEntry)
        case subscribed
        case fetch(ConfigEntry)
    }

    private enum ConfigChangedState {
        case unchanged
        case changed(ConfigEntry)
        case closed(ConfigEntry)
    }

    private let snapshotBuilder: SnapshotBuilderProtocol
    private let log: InternalLogger
    private let fetcher: ConfigFetcher
    private let cache: ConfigCache?
    private let pollingMode: PollingMode
    private let hooks: Hooks
    private let cacheKey: String
    private let serviceState: Locked<ServiceState>

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
        self.serviceState = Locked(ServiceState(offline: offline))
        cacheKey = Utils.generateCacheKey(sdkKey: sdkKey)
    }

    func start() {
        if let autoPoll = pollingMode as? AutoPollingMode {
            serviceState.withLock { state in
                if state.closed || state.started { return }

                state.started = true
                startPoll(interval: autoPoll.autoPollIntervalInSeconds, state: state)

                // Waiting for the client initialization.
                // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while the config is not ready
                // the default value will be returned.
                state.initTimer = DispatchSource.makeTimerSource()
                state.initTimer?.schedule(deadline: .now() + .seconds(autoPoll.maxInitWaitTimeInSeconds))
                state.initTimer?.setEventHandler(handler: { [weak self] in
                    guard let this = self else {
                        return
                    }
                    // Max wait time expired without result, notify subscribers with the cached config.
                    let ready = this.serviceState.withLock { (state) -> (InMemoryResult, [@Sendable (ConfigCatClientSnapshot) -> Void], MutableQueue<@Sendable (FetchResult) -> Void>?, [@Sendable (ClientCacheState) -> ()])? in
                        guard !state.initialized && !state.closed else { return nil }
                        state.initialized = true
                        let result = this.produceInMemoryResult(entry: state.cachedEntry)
                        state.readyState = result.cacheState
                        let readyCallbacks = this.hooks.snapshotReadyCallbacks()
                        return (result, readyCallbacks, state.takeAndClearCompletions(), state.takeAndClearReadyWaiters())
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
                state.initTimer?.resume()
            }
        } else {
            let shouldSync = serviceState.withLock { state in
                if state.closed || state.started { return false }
                state.started = true
                return true
            }
            if shouldSync {
                fetchIfOlder(threshold: Date.distantPast, preferCache: true) { _ in }
            }
        }
    }

    func close() {
        let entryAndCompletions = serviceState.withLock { (state) -> (ConfigEntry, ClientCacheState, MutableQueue<@Sendable (FetchResult) -> Void>?, [@Sendable (ClientCacheState) -> ()])? in
            guard !state.closed else {
                return nil
            }
            state.closed = true
            let readyState = state.readyState ?? ConfigService.determineReadyState(entry: state.cachedEntry, pollingMode: pollingMode)
            if state.readyState == nil {
                state.readyState = readyState
            }
            state.pollTimer?.cancel()
            state.initTimer?.cancel()
            return (state.cachedEntry, readyState, state.takeAndClearCompletions(), state.takeAndClearReadyWaiters())
        }
        if let (entry, readyState, pendingCompletions, readyWaiters) = entryAndCompletions {
            unblockReadyWaiters(waiters: readyWaiters, cacheState: readyState)
            callCompletions(pendingCompletions, result: .success(entry))
        }
    }

    func settings(completion: @escaping @Sendable (SettingsResult) -> Void) {
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

    func refresh(completion: @escaping @Sendable (RefreshResult) -> Void) {
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
        let stateChanged = serviceState.withLock { state in
            if state.closed || !state.offline {
                return false
            }
            state.offline = false
            if !state.started {
                return true
            }
            state.pollTimer?.cancel()
            state.pollTimer = nil
            if let autoPoll = pollingMode as? AutoPollingMode {
                startPoll(interval: autoPoll.autoPollIntervalInSeconds, state: state)
            }
            return true
        }
        if stateChanged {
            log.info(eventId: 5200, message: "Switched to ONLINE mode.")
        }
    }

    func setOffline() {
        let stateChanged = serviceState.withLock { state in
            if state.closed || state.offline {
                return false
            }
            state.offline = true
            return true
        }
        if stateChanged {
            log.info(eventId: 5200, message: "Switched to OFFLINE mode.")
        }
    }

    func waitForReady(handler: @escaping @Sendable (ClientCacheState) -> ()) {
        let state: ClientCacheState? = serviceState.withLock { state in
            if state.initialized || state.closed {
                return state.readyState
            }
            state.readyWaiters.append(handler)
            return nil
        }
        if let state = state {
            handler(state)
        }
    }

    var isOffline: Bool {
        return serviceState.withLock { state in
            state.offline
        }
    }

    var inMemory: InMemoryResult {
        return serviceState.withLock { state in
            return produceInMemoryResult(entry: state.cachedEntry)
        }  
    }

    private var isInitialized: Bool {
        return serviceState.withLock { state in
            state.initialized
        }
    }

    private func fetchIfOlder(
        threshold: Date, preferCache: Bool = false, completion: @escaping @Sendable (FetchResult) -> Void
    ) {
        let entry = readCache()
        let changedState: ConfigChangedState = serviceState.withLock { state in
            if state.closed {
                return .closed(state.cachedEntry)
            }
            if !entry.isEmpty, entry != state.cachedEntry, state.cachedEntry.isEmpty || entry.fetchTime > state.cachedEntry.fetchTime {
                state.cachedEntry = entry
                return .changed(state.cachedEntry)
            }
            return .unchanged
        }

        switch changedState {
        case .closed(let entry):
            completion(.success(entry))
            return  
        case .changed(let entry):
            reportConfigChanged(entry: entry)
        case .unchanged:
            break
        }

        let decision: FetchDecision = serviceState.withLock { state in
            if state.closed {
                return .closed(state.cachedEntry)
            }
            if preferCache || state.offline || state.cachedEntry.fetchTime > threshold {
                return .useCache(state.cachedEntry)
            }
            if state.completions == nil {
                state.completions = MutableQueue()
            }
            state.completions?.enqueue(item: completion)
            guard !state.fetchInProgress else { return .subscribed }
            state.fetchInProgress = true
            return .fetch(state.cachedEntry)
        }

        switch decision {
        case .closed(let entry):
            completion(.success(entry))
        case .useCache(let entry):
            setInitializedAndReportReady(entry: entry)
            completion(.success(entry))
        case .subscribed:
            break
        case .fetch(let entry):
            let etag = entry.isEmpty ? "" : entry.eTag
            fetcher.fetch(eTag: etag) { response in
                self.processResponse(response: response)
            }
        }
    }

    private func processResponse(response: FetchResponse) {
        var completionResult: FetchResult?
        var pendingCompletions: MutableQueue<@Sendable (FetchResult) -> Void>?
        var configChanged = false
        var writeEntryToCache = true
        let currentEntry: ConfigEntry? = serviceState.withLock { state in
            guard !state.closed else { return nil }

            switch response {
            case .fetched(let entry):
                state.cachedEntry = entry
                configChanged = true
                completionResult = .success(entry)
            case .notModified:
                state.cachedEntry = state.cachedEntry.withFetchTime(time: Date())
                completionResult = .success(state.cachedEntry)
            case .failure(let error, let errorCode, let isTransient):
                if !isTransient && !state.cachedEntry.isEmpty {
                    state.cachedEntry = state.cachedEntry.withFetchTime(time: Date())
                } else {
                    writeEntryToCache = false
                }
                completionResult = .failure(error, errorCode, state.cachedEntry)
                
            }
            state.fetchInProgress = false
            pendingCompletions = state.takeAndClearCompletions()
            return state.cachedEntry
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
        let ready = serviceState.withLock { (state) -> (InMemoryResult, [@Sendable (ConfigCatClientSnapshot) -> ()], [@Sendable (ClientCacheState) -> ()])? in
            guard !state.initialized && !state.closed else { return nil }
            state.initialized = true
            let result = produceInMemoryResult(entry: entry)
            state.readyState = result.cacheState
            let readyCallbacks = hooks.snapshotReadyCallbacks()
            return (result, readyCallbacks, state.takeAndClearReadyWaiters())
        }
        if let (result, readyCallbacks, readyWaiters) = ready {
            unblockReadyWaiters(waiters: readyWaiters, cacheState: result.cacheState)
            hooks.invokeReadyCallbacks(callbacks: readyCallbacks, snapshotBuilder: snapshotBuilder, inMemoryResult: result)
        }
    }

    private func reportConfigChanged(entry: ConfigEntry) {
        hooks.invokeOnConfigChanged(snapshotBuilder: snapshotBuilder, inMemoryResult: produceInMemoryResult(entry: entry))
    }

    private func callCompletions(_ pending: MutableQueue<@Sendable (FetchResult) -> Void>?, result: FetchResult) {
        if let completions = pending {
            while !completions.isEmpty {
                guard let current = completions.dequeue() else {
                    return
                }
                current(result)
            }
        }
    }

    private func unblockReadyWaiters(waiters: [@Sendable (ClientCacheState) -> ()], cacheState: ClientCacheState) {
        for waiter in waiters {
            waiter(cacheState)
        }
    }

    private func startPoll(interval: Int, state: ServiceState) {
        let ageThreshold = Int(Double(interval) * 0.8)
        state.startPoll(interval: interval, handler: { [weak self] in
            guard let this = self else {
                return
            }
            this.log.debug(message: "Polling for config.json changes.")
            this.fetchIfOlder(threshold: Date().addingTimeInterval(-TimeInterval(ageThreshold))) { _ in
                // we don't have to do anything with the result in the timer ticks.
            }
        })
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
        let entryStringAtReadStart = serviceState.withLock { $0.cachedEntry.cacheString }
        do {
            let json = try cache.read(for: cacheKey)
            if json.isEmpty || json == entryStringAtReadStart {
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
        return InMemoryResult(entry: entry, cacheState: ConfigService.determineReadyState(entry: entry, pollingMode: pollingMode))
    }

    private static func determineReadyState(entry: ConfigEntry, pollingMode: PollingMode) -> ClientCacheState {
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

    /// This class is only used inside Locked, so it can't be modified without holding a mutex.
    private final class ServiceState: @unchecked Sendable {
        var started: Bool = false
        var initialized: Bool = false
        var offline: Bool = false
        var closed: Bool = false
        var cachedEntry: ConfigEntry = .empty
        var completions: MutableQueue<@Sendable (FetchResult) -> Void>?
        var readyWaiters: [@Sendable (ClientCacheState) -> ()] = []
        var readyState: ClientCacheState?
        var fetchInProgress = false
        var pollTimer: DispatchSourceTimer? = nil
        var initTimer: DispatchSourceTimer? = nil

        init(offline: Bool) {
            self.offline = offline
        }

        func takeAndClearCompletions() -> MutableQueue<@Sendable (FetchResult) -> Void>? {
            let pending = completions
            completions = nil
            return pending
        }

        func takeAndClearReadyWaiters() -> [@Sendable (ClientCacheState) -> ()] {
            let waiters = readyWaiters
            readyWaiters = []
            return waiters
        }

        func startPoll(interval: Int, handler: @escaping () -> Void) {
            pollTimer = DispatchSource.makeTimerSource()
            pollTimer?.schedule(deadline: .now(), repeating: .seconds(interval))
            pollTimer?.setEventHandler(handler: handler)
            pollTimer?.resume()
        }
    }
}
