import Foundation

public class EvaluationDetailsBase: NSObject {
    /// Key of the feature flag or setting.
    @objc public let key: String
    /// Variation ID of the feature flag or setting (if available).
    @objc public let variationId: String?
    /// The User Object used for the evaluation (if available).
    @objc public let user: ConfigCatUser?
    /// Indicates whether the default value passed to the setting evaluation methods is used as the result of the evaluation.
    @objc public let isDefaultValue: Bool
    /// Error message in case evaluation failed.
    @objc public let error: String?
    /// Time of last successful config download.
    @objc public let fetchTime: Date
    /// The targeting rule (if any) that matched during the evaluation and was used to return the evaluated value.
    @objc public let matchedTargetingRule: TargetingRule?
    /// The percentage option (if any) that was used to select the evaluated value.
    @objc public let matchedPercentageOption: PercentageOption?

    init(key: String,
         variationId: String?,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedTargetingRule: TargetingRule? = nil,
         matchedPercentageOption: PercentageOption? = nil) {
        self.key = key
        self.variationId = variationId
        self.user = user
        self.fetchTime = fetchTime
        self.isDefaultValue = isDefaultValue
        self.error = error
        self.matchedTargetingRule = matchedTargetingRule
        self.matchedPercentageOption = matchedPercentageOption
    }
}

public final class EvaluationDetails: EvaluationDetailsBase {
    @objc public let value: Any

    init(key: String,
         value: Any,
         variationId: String?,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedTargetingRule: TargetingRule? = nil,
         matchedPercentageOption: PercentageOption? = nil) {
        self.value = value
        super.init(key: key, variationId: variationId, fetchTime: fetchTime, user: user, isDefaultValue: isDefaultValue, error: error, matchedTargetingRule: matchedTargetingRule, matchedPercentageOption: matchedPercentageOption)
    }

    static func fromError(key: String, value: Any, error: String, user: ConfigCatUser?) -> EvaluationDetails {
        EvaluationDetails(key: key, value: value, variationId: "", user: user, isDefaultValue: true, error: error)
    }
}

public final class StringEvaluationDetails: EvaluationDetailsBase {
    /// Evaluated value of the feature flag or setting.
    @objc public let value: String

    init(value: String,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class BoolEvaluationDetails: EvaluationDetailsBase {
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Bool

    init(value: Bool,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class IntEvaluationDetails: EvaluationDetailsBase {
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Int

    init(value: Int,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class DoubleEvaluationDetails: EvaluationDetailsBase {
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Double

    init(value: Double,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class TypedEvaluationDetails<Value>: EvaluationDetailsBase {
    /// Evaluated value of the feature flag or setting.
    public let value: Value

    init(key: String,
         value: Value,
         variationId: String?,
         fetchTime: Date = Date.distantPast,
         user: ConfigCatUser? = nil,
         isDefaultValue: Bool = false,
         error: String? = nil,
         matchedTargetingRule: TargetingRule? = nil,
         matchedPercentageOption: PercentageOption? = nil) {
        self.value = value
        super.init(key: key, variationId: variationId, fetchTime: fetchTime, user: user, isDefaultValue: isDefaultValue, error: error, matchedTargetingRule: matchedTargetingRule, matchedPercentageOption: matchedPercentageOption)
    }

    static func fromError(key: String, value: Value, error: String, user: ConfigCatUser?) -> TypedEvaluationDetails<Value> {
        TypedEvaluationDetails<Value>(key: key, value: value, variationId: "", user: user, isDefaultValue: true, error: error)
    }

    func toStringDetails() -> StringEvaluationDetails {
        StringEvaluationDetails(value: value as? String ?? "", base: self)
    }

    func toBoolDetails() -> BoolEvaluationDetails {
        BoolEvaluationDetails(value: value as? Bool ?? false, base: self)
    }

    func toIntDetails() -> IntEvaluationDetails {
        IntEvaluationDetails(value: value as? Int ?? 0, base: self)
    }

    func toDoubleDetails() -> DoubleEvaluationDetails {
        DoubleEvaluationDetails(value: value as? Double ?? 0, base: self)
    }
}
