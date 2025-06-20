import Foundation

class FlagEvaluator {
    private let log: InternalLogger
    private let evaluator: RolloutEvaluator
    private let hooks: Hooks

    init(log: InternalLogger, evaluator: RolloutEvaluator, hooks: Hooks) {
        self.log = log
        self.evaluator = evaluator
        self.hooks = hooks
    }

    func validateFlagType<Value>(
        of: Value.Type,
        key: String,
        defaultValue: Any,
        user: ConfigCatUser?
    ) -> EvaluationDetails? {
        if of != String.self && of != String?.self && of != Int.self
            && of != Int?.self && of != Double.self && of != Double?.self
            && of != Bool.self && of != Bool?.self && of != Any.self
            && of != Any?.self
        {
            let message =
                "Only the following types are supported: String, Int, Double, Bool, and Any (both nullable and non-nullable)."
            log.error(eventId: 2022, message: message)
            let details = EvaluationDetails.fromError(
                key: key,
                value: defaultValue,
                error: message,
                errorCode: .invalidUserInput,
                user: user
            )
            hooks.invokeOnFlagEvaluated(
                details: details
            )
            return details
        }

        return nil
    }

    func evaluateFlag<Value>(
        result: SettingsResult,
        key: String,
        defaultValue: Value,
        user: ConfigCatUser?
    ) -> TypedEvaluationDetails<Value> {
        if result.settings.isEmpty {
            let message = String(
                format:
                    "Config JSON is not present when evaluating setting '%@'. Returning the `defaultValue` parameter that you specified in your application: '%@'.",
                key,
                "\(defaultValue)"
            )
            self.log.error(eventId: 1000, message: message)
            let details = EvaluationDetails.fromError(
                key: key,
                value: defaultValue,
                error: message,
                errorCode: .configJsonNotAvailable,
                user: user
            )
            self.hooks.invokeOnFlagEvaluated(
                details: details
            )
            return TypedEvaluationDetails<Value>.fromError(
                value: defaultValue,
                details: details
            )
        }
        guard let setting = result.settings[key] else {
            let message = String(
                format:
                    "Failed to evaluate setting '%@' (the key was not found in config JSON). "
                    + "Returning the `defaultValue` parameter that you specified in your application: '%@'. Available keys: [%@].",
                key,
                "\(defaultValue)",
                result.settings.keys.map { key in
                    return "'" + key + "'"
                }.joined(separator: ", ")
            )
            self.log.error(eventId: 1001, message: message)
            let details = EvaluationDetails.fromError(
                key: key,
                value: defaultValue,
                error: message,
                errorCode: .settingKeyMissing,
                user: user
            )
            self.hooks.invokeOnFlagEvaluated(
                details: details
            )
            return TypedEvaluationDetails<Value>.fromError(
                value: defaultValue,
                details: details
            )
        }
        let evaluationResult = evaluator.evaluate(
            setting: setting,
            key: key,
            user: user,
            settings: result.settings,
            defaultValue: defaultValue
        )
        switch evaluationResult {
        case .success(let value, let variationId, let rule, let option):
            guard let typedValue = value as? Value else {
                let message =
                    "The type of a setting must match the type of the specified default value. Setting's type was \(setting.settingType.text) but the default value's type was \(Value.self). Please use a default value which corresponds to the setting type \(setting.settingType.text). Learn more: https://configcat.com/docs/sdk-reference/ios/#setting-type-mapping"
                self.log.error(eventId: 2002, message: message)
                let details = EvaluationDetails.fromError(
                    key: key,
                    value: defaultValue,
                    error: message,
                    errorCode: .settingValueTypeMismatch,
                    user: user
                )
                self.hooks.invokeOnFlagEvaluated(
                    details: details
                )
                return TypedEvaluationDetails<Value>.fromError(
                    value: defaultValue,
                    details: details
                )
            }

            let details = EvaluationDetails(
                key: key,
                value: typedValue,
                variationId: variationId,
                fetchTime: result.fetchTime,
                user: user,
                errorCode: .none,
                matchedTargetingRule: rule,
                matchedPercentageOption: option
            )
            hooks.invokeOnFlagEvaluated(
                details: details
            )
            return TypedEvaluationDetails<Value>(
                value: typedValue,
                details: details
            )
        case .error(let err):
            let message = "Failed to evaluate setting '\(key)' (\(err))"
            self.log.error(eventId: 1002, message: message)
            let details = EvaluationDetails.fromError(
                key: key,
                value: defaultValue,
                error: message,
                errorCode: .invalidConfigModel,
                user: user
            )
            self.hooks.invokeOnFlagEvaluated(
                details: details
            )
            return TypedEvaluationDetails<Value>.fromError(
                value: defaultValue,
                details: details
            )
        }
    }

    func evaluateFlag(
        for setting: Setting,
        key: String,
        user: ConfigCatUser?,
        fetchTime: Date,
        settings: [String: Setting]
    ) -> EvaluationDetails? {
        let evaluationResult = evaluator.evaluate(
            setting: setting,
            key: key,
            user: user,
            settings: settings,
            defaultValue: nil
        )
        switch evaluationResult {
        case .success(let value, let variationId, let rule, let option):
            let details = EvaluationDetails(
                key: key,
                value: value,
                variationId: variationId,
                fetchTime: fetchTime,
                user: user,
                errorCode: .none,
                matchedTargetingRule: rule,
                matchedPercentageOption: option
            )
            hooks.invokeOnFlagEvaluated(details: details)
            return details
        case .error(let err):
            let message = "Failed to evaluate setting '\(key)' (\(err))"
            self.log.error(eventId: 1002, message: message)
            return nil
        }
    }
}
