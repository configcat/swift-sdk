import Foundation

public class EvaluationDetailsBase: NSObject {
    @objc public let key: String
    @objc public let variationId: String
    @objc public let user: ConfigCatUser?
    @objc public let isDefaultValue: Bool
    @objc public let error: String?
    @objc public let fetchTime: Date
    @objc public let matchedEvaluationRule: RolloutRule?
    @objc public let matchedEvaluationPercentageRule: PercentageRule?

    init(key: String,
         variationId: String,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedEvaluationRule: RolloutRule? = nil,
         matchedEvaluationPercentageRule: PercentageRule? = nil) {
        self.key = key
        self.variationId = variationId
        self.user = user
        self.fetchTime = fetchTime
        self.isDefaultValue = isDefaultValue
        self.error = error
        self.matchedEvaluationRule = matchedEvaluationRule
        self.matchedEvaluationPercentageRule = matchedEvaluationPercentageRule
    }
}

public final class EvaluationDetails: EvaluationDetailsBase {
    @objc public let value: Any

    init(key: String,
         value: Any,
         variationId: String,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedEvaluationRule: RolloutRule? = nil,
         matchedEvaluationPercentageRule: PercentageRule? = nil) {
        self.value = value
        super.init(key: key, variationId: variationId, fetchTime: fetchTime, user: user, isDefaultValue: isDefaultValue, error: error, matchedEvaluationRule: matchedEvaluationRule, matchedEvaluationPercentageRule: matchedEvaluationPercentageRule)
    }

    static func fromError(key: String, value: Any, error: String) -> EvaluationDetails {
        EvaluationDetails(key: key, value: value, variationId: "", isDefaultValue: true, error: error)
    }
}

public final class TypedEvaluationDetails<Value>: EvaluationDetailsBase {
    public let value: Value

    init(key: String,
         value: Value,
         variationId: String,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedEvaluationRule: RolloutRule? = nil,
         matchedEvaluationPercentageRule: PercentageRule? = nil) {
        self.value = value
        super.init(key: key, variationId: variationId, fetchTime: fetchTime, user: user, isDefaultValue: isDefaultValue, error: error, matchedEvaluationRule: matchedEvaluationRule, matchedEvaluationPercentageRule: matchedEvaluationPercentageRule)
    }

    static func fromError<Value>(key: String, value: Value, error: String) -> TypedEvaluationDetails<Value> {
        TypedEvaluationDetails<Value>(key: key, value: value, variationId: "", isDefaultValue: true, error: error)
    }
}
