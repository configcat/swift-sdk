import Foundation

public final class ConfigCatSnapshot: NSObject {
    private let flagEvaluator: FlagEvaluator
    private let settingsSnapshot: SettingsResult
    private let defaultUser: ConfigCatUser?
    private let log: InternalLogger
    
    init(flagEvaluator: FlagEvaluator, settingsSnapshot: SettingsResult, defaultUser: ConfigCatUser?, log: InternalLogger) {
        self.flagEvaluator = flagEvaluator
        self.settingsSnapshot = settingsSnapshot
        self.defaultUser = defaultUser
        self.log = log
    }
    
    /**
     Gets the value of a feature flag or setting identified by the given `key`.
     
     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Returns: The evaluated feature flag value.
     */
    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser
        
        if let _ = flagEvaluator.validateFlagType(of: Value.self, key: key, defaultValue: defaultValue, user: evalUser) {
            return defaultValue
        }
        
        let evalDetails = self.flagEvaluator.evaluateFlag(result: settingsSnapshot, key: key, defaultValue: defaultValue, user: evalUser)
        return evalDetails.value
    }

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`.

     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Returns: The evaluation details.
     */
    public func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> TypedEvaluationDetails<Value> {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser
        
        if let error = flagEvaluator.validateFlagType(of: Value.self, key: key, defaultValue: defaultValue, user: evalUser) {
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: error, user: evalUser)
        }
        
        let evalDetails = self.flagEvaluator.evaluateFlag(result: settingsSnapshot, key: key, defaultValue: defaultValue, user: evalUser)
        return evalDetails
    }
    
    /// Gets all the setting keys within the snapshot.
    @objc public func getAllKeys() -> [String] {
        if settingsSnapshot.isEmpty {
            log.error(eventId: 1000, message: "Config JSON is not present. Returning empty array.")
            return []
        }
        return [String](settingsSnapshot.settings.keys)
    }
}
