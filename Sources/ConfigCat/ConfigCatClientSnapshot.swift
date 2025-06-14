import Foundation

/// Represents the state of `ConfigCatClient` captured at a specific point in time.
public final class ConfigCatClientSnapshot: NSObject {
    private let flagEvaluator: FlagEvaluator
    private let settingsSnapshot: SettingsResult
    private let defaultUser: ConfigCatUser?
    private let log: InternalLogger

    /**
     The state of the internal cache at the time the snapshot was created.
     */
    @objc public let cacheState: ClientCacheState

    init(
        flagEvaluator: FlagEvaluator,
        settingsSnapshot: SettingsResult,
        cacheState: ClientCacheState,
        defaultUser: ConfigCatUser?,
        log: InternalLogger
    ) {
        self.flagEvaluator = flagEvaluator
        self.settingsSnapshot = settingsSnapshot
        self.defaultUser = defaultUser
        self.log = log
        self.cacheState = cacheState
    }

    /**
     Gets the value of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `Any` (both nullable and non-nullable).
    
     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Returns: The evaluated feature flag value.
     */
    public func getValue<Value>(
        for key: String,
        defaultValue: Value,
        user: ConfigCatUser? = nil
    ) -> Value {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser

        if flagEvaluator.validateFlagType(
            of: Value.self,
            key: key,
            defaultValue: defaultValue,
            user: evalUser
        ) != nil {
            return defaultValue
        }

        let evalDetails = self.flagEvaluator.evaluateFlag(
            result: settingsSnapshot,
            key: key,
            defaultValue: defaultValue,
            user: evalUser
        )
        return evalDetails.value
    }

    /**
     Gets the value and evaluation details of a feature flag or setting identified by the given `key`. The generic parameter `Value` represents the type of the desired feature flag or setting. Only the following types are allowed: `String`, `Bool`, `Int`, `Double`, `Any` (both nullable and non-nullable).
    
     - Parameter key: the identifier of the feature flag or setting.
     - Parameter defaultValue: in case of any failure, this value will be returned.
     - Parameter user: the user object to identify the caller.
     - Returns: The evaluation details.
     */
    public func getValueDetails<Value>(
        for key: String,
        defaultValue: Value,
        user: ConfigCatUser? = nil
    ) -> TypedEvaluationDetails<Value> {
        assert(!key.isEmpty, "key cannot be empty")
        let evalUser = user ?? defaultUser

        if let error = flagEvaluator.validateFlagType(
            of: Value.self,
            key: key,
            defaultValue: defaultValue,
            user: evalUser
        ) {
            return TypedEvaluationDetails<Value>.fromError(
                value: defaultValue,
                details: error
            )
        }

        let evalDetails = self.flagEvaluator.evaluateFlag(
            result: settingsSnapshot,
            key: key,
            defaultValue: defaultValue,
            user: evalUser
        )
        return evalDetails
    }

    /// Gets all the setting keys within the snapshot.
    @objc public func getAllKeys() -> [String] {
        if settingsSnapshot.isEmpty {
            log.error(
                eventId: 1000,
                message: "Config JSON is not present. Returning empty array."
            )
            return []
        }
        return [String](settingsSnapshot.settings.keys)
    }
}
