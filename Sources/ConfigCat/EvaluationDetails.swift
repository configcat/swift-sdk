import Foundation

public class EvaluationDetailsBase: NSObject {
    @objc public let key: String
    @objc public let variationId: String?
    @objc public let user: ConfigCatUser?
    @objc public let isDefaultValue: Bool
    @objc public let error: String?
    @objc public let fetchTime: Date
    @objc public let matchedTargetingRule: TargetingRule?
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
    @objc public let value: String

    init(value: String,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class BoolEvaluationDetails: EvaluationDetailsBase {
    @objc public let value: Bool

    init(value: Bool,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class IntEvaluationDetails: EvaluationDetailsBase {
    @objc public let value: Int

    init(value: Int,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class DoubleEvaluationDetails: EvaluationDetailsBase {
    @objc public let value: Double

    init(value: Double,
         base: EvaluationDetailsBase) {
        self.value = value
        super.init(key: base.key, variationId: base.variationId, fetchTime: base.fetchTime, user: base.user, isDefaultValue: base.isDefaultValue, error: base.error, matchedTargetingRule: base.matchedTargetingRule, matchedPercentageOption: base.matchedPercentageOption)
    }
}

public final class TypedEvaluationDetails<Value>: EvaluationDetailsBase {
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
