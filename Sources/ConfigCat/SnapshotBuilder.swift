protocol SnapshotBuilderProtocol {
    func buildSnapshot(inMemoryResult: InMemoryResult?) -> ConfigCatClientSnapshot
    var defaultUser: ConfigCatUser? { get set }
}

class SnapshotBuilder: SnapshotBuilderProtocol {
    private let flagEvaluator: FlagEvaluator
    @Synced public var defaultUser: ConfigCatUser?
    private let overrideDataSource: OverrideDataSource?
    private let log: InternalLogger
    
    init(
        flagEvaluator: FlagEvaluator,
        defaultUser: ConfigCatUser?,
        overrideDataSource: OverrideDataSource?,
        log: InternalLogger
    ) {
        self.flagEvaluator = flagEvaluator
        self.defaultUser = defaultUser
        self.overrideDataSource = overrideDataSource
        self.log = log
    }
  
    public func buildSnapshot(inMemoryResult: InMemoryResult?) -> ConfigCatClientSnapshot {
        let inMemorySettings = calcInMemorySettingsWithOverrides(inMemoryResult: inMemoryResult)
        return ConfigCatClientSnapshot(
            flagEvaluator: flagEvaluator,
            settingsSnapshot: inMemorySettings.0,
            cacheState: inMemorySettings.1,
            defaultUser: defaultUser,
            log: log
        )
    }
    
    func calcInMemorySettingsWithOverrides(inMemoryResult: InMemoryResult?) -> (SettingsResult, ClientCacheState) {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            return (SettingsResult(settings: overrideDataSource.getOverrides(), fetchTime: .distantPast), ClientCacheState.hasLocalOverrideFlagDataOnly)
        }
        guard let inMemoryResult = inMemoryResult else {
            return (.empty, ClientCacheState.noFlagData)
        }
        
        let entry = inMemoryResult.entry
        
        if let overrideDataSource = overrideDataSource {
            if overrideDataSource.behaviour == .localOverRemote {
                return (SettingsResult(settings: entry.config.settings.merging(overrideDataSource.getOverrides()) { (_, new) in
                    new
                }, fetchTime: entry.fetchTime), inMemoryResult.cacheState)
            }
            if overrideDataSource.behaviour == .remoteOverLocal {
                return (SettingsResult(settings: entry.config.settings.merging(overrideDataSource.getOverrides()) { (current, _) in
                    current
                }, fetchTime: entry.fetchTime), inMemoryResult.cacheState)
            }
        }
        
        return (SettingsResult(settings: entry.config.settings, fetchTime: entry.fetchTime), inMemoryResult.cacheState)
    }
}
