import Foundation

/// Specifies the possible evaluation error codes.
@objc public enum EvaluationErrorCode: Int, Sendable {
    /** Invalid arguments were passed to the evaluation method. */
    case invalidUserInput = -2
    /** An unexpected error occurred during the evaluation. */
    case unexpectedError = -1
    /** No error occurred (the evaluation was successful). */
    case none = 0
    /** The evaluation failed because of an error in the config model. (Most likely, invalid data was passed to the SDK via flag overrides.) */
    case invalidConfigModel = 1
    /** The evaluation failed because of a type mismatch between the evaluated setting value and the specified default value. */
    case settingValueTypeMismatch = 2
    /** The evaluation failed because the config JSON was not available locally. */
    case configJsonNotAvailable = 1000
    /** The evaluation failed because the key of the evaluated setting was not found in the config JSON. */
    case settingKeyMissing = 1001
}

/// Metadata describing how a feature flag or setting was evaluated.
public final class EvaluationMetadata: NSObject, Sendable {
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
    /// The code identifying the reason for the error in case evaluation failed.
    @objc public let errorCode: EvaluationErrorCode
    /// Time of last successful config download.
    @objc public let fetchTime: Date
    /// The targeting rule (if any) that matched during the evaluation and was used to return the evaluated value.
    @objc public let matchedTargetingRule: TargetingRule?
    /// The percentage option (if any) that was used to select the evaluated value.
    @objc public let matchedPercentageOption: PercentageOption?

    fileprivate init(
        key: String,
        variationId: String?,
        fetchTime: Date,
        user: ConfigCatUser?,
        isDefaultValue: Bool,
        errorCode: EvaluationErrorCode,
        error: String?,
        matchedTargetingRule: TargetingRule?,
        matchedPercentageOption: PercentageOption?
    ) {
        self.key = key
        self.variationId = variationId
        self.user = user
        self.fetchTime = fetchTime
        self.isDefaultValue = isDefaultValue
        self.errorCode = errorCode
        self.error = error
        self.matchedTargetingRule = matchedTargetingRule
        self.matchedPercentageOption = matchedPercentageOption
    }
}

/// Provides the metadata shared by evaluation detail types.
public protocol HasEvaluationMetadata {
    /// Metadata associated with the evaluation of the feature flag or setting.
    var metadata: EvaluationMetadata { get }
}

public extension HasEvaluationMetadata {
    /// Key of the feature flag or setting.
    var key: String { metadata.key }
    /// Variation ID of the feature flag or setting, if available.
    var variationId: String? { metadata.variationId }
    /// The User Object used for evaluation, if available.
    var user: ConfigCatUser? { metadata.user }
    /// Whether the specified default value was returned.
    var isDefaultValue: Bool { metadata.isDefaultValue }
    /// Error message, if evaluation failed.
    var error: String? { metadata.error }
    /// Code identifying the evaluation error.
    var errorCode: EvaluationErrorCode { metadata.errorCode }
    /// Time of the last successful config download.
    var fetchTime: Date { metadata.fetchTime }
    /// The targeting rule matched during evaluation, if any.
    var matchedTargetingRule: TargetingRule? { metadata.matchedTargetingRule }
    /// The percentage option matched during evaluation, if any.
    var matchedPercentageOption: PercentageOption? { metadata.matchedPercentageOption }
}

public final class EvaluationDetails: NSObject, HasEvaluationMetadata {
    /// Metadata associated with the evaluation of the feature flag or setting.
    @objc public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting. `FlagValue` values are exposed as their underlying primitive values.
    @objc public let value: Any

    init(
        key: String,
        value: Any,
        variationId: String?,
        fetchTime: Date = Date.distantPast,
        user: ConfigCatUser? = nil,
        isDefaultValue: Bool = false,
        errorCode: EvaluationErrorCode,
        error: String? = nil,
        matchedTargetingRule: TargetingRule? = nil,
        matchedPercentageOption: PercentageOption? = nil
    ) {
        self.value = (value as? FlagValue)?.rawValue ?? value
        self.metadata = EvaluationMetadata(
            key: key,
            variationId: variationId,
            fetchTime: fetchTime,
            user: user,
            isDefaultValue: isDefaultValue,
            errorCode: errorCode,
            error: error,
            matchedTargetingRule: matchedTargetingRule,
            matchedPercentageOption: matchedPercentageOption
        )
    }

    static func fromError(
        key: String,
        value: Any,
        error: String,
        errorCode: EvaluationErrorCode,
        user: ConfigCatUser?
    ) -> EvaluationDetails {
        EvaluationDetails(
            key: key,
            value: value,
            variationId: "",
            user: user,
            isDefaultValue: true,
            errorCode: errorCode,
            error: error
        )
    }
}

public final class StringEvaluationDetails: NSObject, HasEvaluationMetadata, Sendable {
    /// Metadata associated with the evaluation of the feature flag or setting.
    @objc public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting.
    @objc public let value: String

    init(value: String, metadata: EvaluationMetadata) {
        self.value = value
        self.metadata = metadata
    }
}

public final class BoolEvaluationDetails: NSObject, HasEvaluationMetadata, Sendable {
    /// Metadata associated with the evaluation of the feature flag or setting.
    @objc public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Bool

    init(value: Bool, metadata: EvaluationMetadata) {
        self.value = value
        self.metadata = metadata
    }
}

public final class IntEvaluationDetails: NSObject, HasEvaluationMetadata, Sendable {
    /// Metadata associated with the evaluation of the feature flag or setting.
    @objc public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Int

    init(value: Int, metadata: EvaluationMetadata) {
        self.value = value
        self.metadata = metadata
    }
}

public final class DoubleEvaluationDetails: NSObject, HasEvaluationMetadata, Sendable {
    /// Metadata associated with the evaluation of the feature flag or setting.
    @objc public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting.
    @objc public let value: Double

    init(value: Double, metadata: EvaluationMetadata) {
        self.value = value
        self.metadata = metadata
    }
}

public struct TypedEvaluationDetails<Value>: HasEvaluationMetadata {
    /// Metadata associated with the evaluation of the feature flag or setting.
    public let metadata: EvaluationMetadata
    /// Evaluated value of the feature flag or setting.
    public let value: Value

    init(
        value: Value,
        details: EvaluationDetails
    ) {
        self.value = value
        self.metadata = details.metadata
    }

    static func fromError(
        value: Value,
        details: EvaluationDetails
    ) -> TypedEvaluationDetails<Value> {
        TypedEvaluationDetails<Value>(
            value: value,
            details: details
        )
    }

    func toStringDetails() -> StringEvaluationDetails {
        StringEvaluationDetails(value: value as? String ?? "", metadata: metadata)
    }

    func toBoolDetails() -> BoolEvaluationDetails {
        BoolEvaluationDetails(value: value as? Bool ?? false, metadata: metadata)
    }

    func toIntDetails() -> IntEvaluationDetails {
        IntEvaluationDetails(value: value as? Int ?? 0, metadata: metadata)
    }

    func toDoubleDetails() -> DoubleEvaluationDetails {
        DoubleEvaluationDetails(value: value as? Double ?? 0, metadata: metadata)
    }
}

extension TypedEvaluationDetails: Sendable where Value: Sendable {}
