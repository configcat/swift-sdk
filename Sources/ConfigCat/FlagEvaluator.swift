import Foundation

class FlagEvaluator {
    private let log: Logger
    private let evaluator: RolloutEvaluator
    private let hooks: Hooks
    
    init(log: Logger, evaluator: RolloutEvaluator, hooks: Hooks) {
        self.log = log
        self.evaluator = evaluator
        self.hooks = hooks
    }
    
    func validateFlagType<Value>(of: Value.Type, key: String, defaultValue: Any, user: ConfigCatUser?) -> String? {
        if of != String.self &&
            of != String?.self &&
            of != Int.self &&
            of != Int?.self &&
            of != Double.self &&
            of != Double?.self &&
            of != Bool.self &&
            of != Bool?.self &&
            of != Any.self &&
            of != Any?.self {
            let message = "Only String, Integer, Double, Bool or Any types are supported."
            log.error(eventId: 2022, message: message)
            hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                    value: defaultValue,
                    error: message,
                    user: user))
            return message
        }
        
        return nil
    }
    
    func evaluateFlag<Value>(result: SettingResult, key: String, defaultValue: Value, user: ConfigCatUser?) -> TypedEvaluationDetails<Value> {
        if result.settings.isEmpty {
            let message = String(format: "Config JSON is not present when evaluating setting '%@'. Returning the `defaultValue` parameter that you specified in your application: '%@'.",
                key, "\(defaultValue)")
            self.log.error(eventId: 1000, message: message)
            self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                                                                                  value: defaultValue,
                                                                                  error: message,
                                                                                  user: user))
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message, user: user)
        }
        guard let setting = result.settings[key] else {
            let message = String(format: "Failed to evaluate setting '%@' (the key was not found in config JSON). "
                                 + "Returning the `defaultValue` parameter that you specified in your application: '%@'. Available keys: [%@].", key, "\(defaultValue)", result.settings.keys.map { key in
                return "'"+key+"'"
            }.joined(separator: ", "))
            self.log.error(eventId: 1001, message: message)
            self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                                                                                  value: defaultValue,
                                                                                  error: message,
                                                                                  user: user))
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message, user: user)
        }

        let evaluationResult = self.evaluateRules(for: setting, key: key, user: user, fetchTime: result.fetchTime)
        
        guard let typedValue = evaluationResult.value as? Value else {
            let message = String(format: "Failed to evaluate setting '%@' (the value '%@' cannot be converted to the requested type). "
                + "Returning the `defaultValue` parameter that you specified in your application: '%@'.",
                key, "\(evaluationResult.value)", "\(defaultValue)")
            self.log.error(eventId: 2002, message: message)
            self.hooks.invokeOnFlagEvaluated(details: EvaluationDetails.fromError(key: key,
                                                                                  value: defaultValue,
                                                                                  error: message,
                                                                                  user: user))
            return TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: message, user: user)
        }
        
        return TypedEvaluationDetails<Value>(key: key,
                                             value: typedValue,
                                             variationId: evaluationResult.variationId ?? "",
                                             fetchTime: result.fetchTime,
                                             user: user,
                                             matchedEvaluationRule: evaluationResult.matchedEvaluationRule,
                                             matchedEvaluationPercentageRule: evaluationResult.matchedEvaluationPercentageRule)
    }
    
    func evaluateRules(for setting: Setting, key: String, user: ConfigCatUser?, fetchTime: Date) -> EvaluationDetails {
        let (value, variationId, evaluateLog, rolloutRule, percentageRule): (Any, String?, String?, RolloutRule?, PercentageRule?) = evaluator.evaluate(setting: setting, key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(eventId: 5000, message: evaluateLog)
        }
        let details = EvaluationDetails(key: key,
                value: value,
                variationId: variationId,
                fetchTime: fetchTime,
                user: user,
                matchedEvaluationRule: rolloutRule,
                matchedEvaluationPercentageRule: percentageRule)
        hooks.invokeOnFlagEvaluated(details: details)
        return details
    }
}
