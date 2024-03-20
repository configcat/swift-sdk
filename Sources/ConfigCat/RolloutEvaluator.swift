import Foundation
import CommonCrypto
import os.log

#if SWIFT_PACKAGE
import Version
#endif

enum EvalConditionResult {
    case success(Bool)
    case noUser
    case attributeMissing(UserCondition)
    case attributeInvalid(String, UserCondition)
    case compValueInvalid(String?)
    case fatal(String)
    
    var isSuccess: Bool {
        if case .success(_) = self {
            return true
        }
        return false
    }
    
    var isMatch: Bool {
        if case .success(let match) = self {
            return match
        }
        return false
    }
    
    var isAttributeMissing: Bool {
        if case .attributeMissing(_) = self {
            return true
        }
        return false
    }
    
    var err: String {
        switch self {
        case .success(_):
            return ""
        case .noUser:
            return "cannot evaluate, User Object is missing"
        case .attributeMissing(let cond):
            return "cannot evaluate, the User.\(cond.unwrappedComparisonAttribute) attribute is missing"
        case .attributeInvalid(let reason, let cond):
            return "cannot evaluate, the User.\(cond.unwrappedComparisonAttribute) attribute is invalid (\(reason))"
        case .compValueInvalid(let err):
            return "cannot evaluate, (\(err ?? "comparison value is missing or invalid"))"
        case .fatal(let err):
            return "cannot evaluate (\(err))"
        }
    }
}

enum EvalPercentageResult {
    case success(PercentageOption)
    case userAttrMissing(String)
    case fatal(String)
}

enum EvalResult {
    case success(Any, String?, TargetingRule?, PercentageOption?)
    case error(String)
}

class RolloutEvaluator {
    static let ruleIgnoredMessage = "The current targeting rule is ignored and the evaluation continues with the next rule."
    static let saltMissingMessage = "Config JSON salt is missing"
    static let invalidValueText = "<invalid value>"
    private let log: InternalLogger;

    init(logger: InternalLogger) {
        log = logger
    }

    func evaluate(setting: Setting, key: String, user: ConfigCatUser?, settings: [String: Setting], defaultValue: Any?) -> EvalResult {
        let evalLogger = log.enabled(level: .info) ? EvaluationLogger() : nil
        var cycleTracker: [String] = []
        
        evalLogger?.append(value: "Evaluating '\(key)'")
        if let usr = user {
            evalLogger?.append(value: " for User '\(usr.description)'")
        }
        evalLogger?.incIndent()
        
        let result = setting.settingType == .unknown ? .error("Setting type is invalid") : evalSetting(setting: setting, key: key, user: user, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
        
        if case .success(let val, _, _, _) = result {
            evalLogger?.newLine(msg: "Returning '\(val)'.")
        } else {
            evalLogger?.resetIndent().incIndent()
            evalLogger?.newLine(msg: "Returning '\(defaultValue ?? "nil")'.")
        }
        
        evalLogger?.decIndent()
        if log.enabled(level: .info) {
            log.info(eventId: 5000, message: evalLogger?.content ?? "")
        }
        
        return result
    }
    
    private func evalSetting(setting: Setting, key: String, user: ConfigCatUser?, evalLogger: EvaluationLogger?, settings: [String: Setting], cycleTracker: inout [String]) -> EvalResult {
        var userMissingLogged = false
        
        if !setting.targetingRules.isEmpty {
            evalLogger?.newLine(msg: "Evaluating targeting rules and applying the first match if any:")
            for rule in setting.targetingRules {
                let result = evalConditions(targetingRule: rule, key: key, user: user, salt: setting.salt, ctxSalt: key, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
                if !result.isSuccess {
                    evalLogger?.incIndent().newLine(msg: RolloutEvaluator.ruleIgnoredMessage).decIndent()
                }
                switch result {
                case .success(true):
                    if let servedValue = rule.servedValue {
                        return evalResult(value: servedValue.value, settingType: setting.settingType, variationId: servedValue.variationId, rule: rule, opt: nil)
                    }
                    evalLogger?.incIndent()
                    if !rule.percentageOptions.isEmpty {
                        if let usr = user {
                            let percResult = evalPercentageOptions(opts: rule.percentageOptions, user: usr, key: key, percentageAttr: setting.percentageAttribute, evalLogger: evalLogger)
                            switch percResult {
                            case .success(let opt):
                                evalLogger?.decIndent()
                                return evalResult(value: opt.servedValue, settingType: setting.settingType, variationId: opt.variationId, rule: rule, opt: opt)
                            case .userAttrMissing(let attr):
                                logAttributeMissing(key: key, attr: attr)
                            case .fatal(let err):
                                return .error(err)
                            }
                        } else {
                            if !userMissingLogged {
                                logUserObjectMissing(key: key)
                                userMissingLogged = true
                            }
                            evalLogger?.newLine(msg: "Skipping % options because the User Object is missing.")
                        }
                    } else {
                        return .error("Targeting rule THEN part is missing or invalid")
                    }
                    evalLogger?.newLine(msg: RolloutEvaluator.ruleIgnoredMessage).decIndent()
                case .success(false):
                    continue
                case .fatal(let err):
                    return .error(err)
                case .noUser:
                    if !userMissingLogged {
                        logUserObjectMissing(key: key)
                        userMissingLogged = true
                    }
                    continue
                case .attributeMissing(let cond):
                    logAttributeMissing(key: key, cond: cond)
                    continue
                case .attributeInvalid(let reason, let cond):
                    logAttributeInvalid(key: key, reason: reason, cond: cond)
                    continue
                case .compValueInvalid(let err):
                    return .error(err ?? "Comparison value is missing or invalid")
                }
            }
        }
        
        if !setting.percentageOptions.isEmpty {
            if let usr = user {
                let percResult = evalPercentageOptions(opts: setting.percentageOptions, user: usr, key: key, percentageAttr: setting.percentageAttribute, evalLogger: evalLogger)
                switch percResult {
                case .success(let opt):
                    return evalResult(value: opt.servedValue, settingType: setting.settingType, variationId: opt.variationId, rule: nil, opt: opt)
                case .userAttrMissing(let attr):
                    logAttributeMissing(key: key, attr: attr)
                case .fatal(let err):
                    return .error(err)
                }
            } else {
                if !userMissingLogged {
                    logUserObjectMissing(key: key)
                }
                evalLogger?.newLine(msg: "Skipping % options because the User Object is missing.")
            }
        }
        return evalResult(value: setting.value, settingType: setting.settingType, variationId: setting.variationId, rule: nil, opt: nil)
    }
    
    private func evalResult(value: SettingValue, settingType: SettingType, variationId: String?, rule: TargetingRule?, opt: PercentageOption?) -> EvalResult {
        let valResult = value.toAnyChecked(settingType: settingType)
        switch valResult {
        case .success(let val):
            return .success(val, variationId, rule, opt)
        case .error(let err):
            return .error(err)
        }
    }
    
    private func evalPercentageOptions(opts: [PercentageOption], user: ConfigCatUser, key: String, percentageAttr: String, evalLogger: EvaluationLogger?) -> EvalPercentageResult {
        guard let attrVal = user.attribute(for: percentageAttr) else {
            evalLogger?.newLine(msg: "Skipping % options because the User.\(percentageAttr) attribute is missing.")
            return .userAttrMissing(percentageAttr)
        }
        evalLogger?.newLine(msg: "Evaluating % options based on the User.\(percentageAttr) attribute:")
        let (stringAttrVal, _) = asString(value: attrVal)
        let hashCandidate = key + stringAttrVal
        let hash = hashCandidate.sha1hex.prefix(7)
        let hashString = String(hash)
        if let num = Int(hashString, radix: 16) {
            let scaled = num % 100
            evalLogger?.newLine(msg: "- Computing hash in the [0..99] range from User.\(percentageAttr) => \(scaled) (this value is sticky and consistent across all SDKs)")
            var bucket = 0
            for (index, opt) in opts.enumerated() {
                bucket += opt.percentage
                if scaled < bucket {
                    evalLogger?.newLine(msg: "- Hash value \(scaled) selects % option \(index + 1) (\(opt.percentage)%), '\(opt.servedValue.anyValue ?? RolloutEvaluator.invalidValueText)'.")
                    return .success(opt)
                }
            }
        }
        return .fatal("Sum of percentage option percentages is less than 100")
    }
    
    private func evalConditions(targetingRule: TargetingRule, key: String, user: ConfigCatUser?, salt: String?, ctxSalt: String, evalLogger: EvaluationLogger?, settings: [String: Setting], cycleTracker: inout [String]) -> EvalConditionResult {
        evalLogger?.newLine(msg: "- ")
        var newLineBeforeThen = false
        
        for (index, cond) in targetingRule.conditions.enumerated() {
            var condResult: EvalConditionResult = .fatal("Condition isn't a type of user, segment, or prerequisite flag condition")
            var matched = true
            if index == 0 {
                evalLogger?.append(value: "IF ").incIndent()
            } else {
                evalLogger?.incIndent().newLine(msg: "AND ")
            }
            
            if let userCondition = cond.userCondition {
                evalLogger?.append(value: userCondition)
                if let usr = user {
                    condResult = evalUserCondition(cond: userCondition, key: key, user: usr, salt: salt, ctxSalt: ctxSalt)
                } else {
                    condResult = .noUser
                }
                newLineBeforeThen = targetingRule.conditions.count > 1
            } else if let segmentCondition = cond.segmentCondition {
                evalLogger?.append(value: segmentCondition)
                if let usr = user {
                    condResult = evalSegmentCondition(cond: segmentCondition, key: key, salt: salt, user: usr, evalLogger: evalLogger)
                } else {
                    condResult = .noUser
                }
                newLineBeforeThen = condResult.isSuccess || condResult.isAttributeMissing || targetingRule.conditions.count > 1
            } else if let prerequisiteFlagCondition = cond.prerequisiteFlagCondition {
                condResult = evalPrerequisiteCondition(cond: prerequisiteFlagCondition, key: key, user: user, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
                newLineBeforeThen = true
            }
            
            if targetingRule.conditions.count > 1 {
                evalLogger?.append(value: " => ").append(value: condResult.isMatch ? "true" : "false").append(value: condResult.isMatch ? "" : ", skipping the remaining AND conditions")
            }
            
            evalLogger?.decIndent()
            
            if case .success(let match) = condResult {
                matched = match
            } else {
                matched = false
            }
            
            if !matched {
                evalLogger?.appendThen(newLine: newLineBeforeThen, result: condResult, targetingRule: targetingRule)
                return condResult
            }
        }
        evalLogger?.appendThen(newLine: newLineBeforeThen, result: .success(true), targetingRule: targetingRule)
        return .success(true)
    }
    
    private func evalSegmentCondition(cond: SegmentCondition, key: String, salt: String?, user: ConfigCatUser, evalLogger: EvaluationLogger?) -> EvalConditionResult {
        guard let userConditions = cond.segment?.conditions else {
            return .fatal("Segment reference is invalid")
        }
        guard let name = cond.segment?.name else {
            return .fatal("Segment name is missing")
        }
        if cond.segmentComparator == .unknown {
            return .fatal("Comparison operator is invalid")
        }
        
        evalLogger?.newLine(msg: "(").incIndent().newLine(msg: "Evaluating segment '\(name)':")
        var result: EvalConditionResult = .fatal("")
        let needsTrue = cond.segmentComparator == .isIn
        
        for (index, userCondition) in userConditions.enumerated() {
            evalLogger?.newLine(msg: "- ")
            if index == 0 {
                evalLogger?.append(value: "IF ").incIndent()
            } else {
                evalLogger?.incIndent().newLine(msg: "AND ")
            }
            evalLogger?.append(value: userCondition)
            result = evalUserCondition(cond: userCondition, key: key, user: user, salt: salt, ctxSalt: name)
            evalLogger?.append(value: " => ").append(value: result.isMatch ? "true" : "false").append(value: result.isMatch ? "" : ", skipping the remaining AND conditions").decIndent()
            
            if !result.isSuccess || !result.isMatch {
                break
            }
        }
        
        evalLogger?.newLine(msg: "Segment evaluation result: ")
            .append(value: !result.isSuccess ? result.err : "User \(result.isMatch ? SegmentComparator.isIn.text : SegmentComparator.isNotIn.text)")
            .append(value: ".")
            .newLine(msg: "Condition (").append(value: cond).append(value: ")")
            .append(value: !result.isSuccess ? " failed to evaluate" : " evaluates to \(result.isMatch == needsTrue ? "true" : "false")")
            .append(value: ".")
            .decIndent()
            .newLine(msg: ")")
        
        if case let .success(match) = result {
            return .success(match == needsTrue)
        }
        return result
    }
    
    private func evalPrerequisiteCondition(cond: PrerequisiteFlagCondition, key: String, user: ConfigCatUser?, evalLogger: EvaluationLogger?, settings: [String: Setting], cycleTracker: inout [String]) -> EvalConditionResult {
        evalLogger?.append(value: cond)
        guard let flagKey = cond.flagKey else {
            return .fatal("Prerequisite flag key is missing")
        }
        guard let prereq = settings[flagKey] else {
            return .fatal("Prerequisite flag is missing")
        }
        if cond.prerequisiteComparator == .unknown {
            return .fatal("Comparison operator is invalid")
        }
        
        let compValChecked = cond.flagValue.toAnyChecked(settingType: prereq.settingType)
        var compVal: Any? = nil
        if case .error(_) = compValChecked, prereq.settingType != .unknown {
            return .fatal("Type mismatch between comparison value '\(cond.flagValue.anyValue ?? "")' and prerequisite flag '\(flagKey)'.")
        }
        if case .success(let val) = compValChecked {
            compVal = val
        }
        cycleTracker.append(key)
        if cycleTracker.contains(flagKey) {
            cycleTracker.append(flagKey)
            let output = cycleTracker.map { c in
                return "'"+c+"'"
            }.joined(separator: " -> ")
            return .fatal("Circular dependency detected between the following depending flags: [\(output)].")
        }
        
        let needsTrue = cond.prerequisiteComparator == .eq
        evalLogger?.newLine(msg: "(").incIndent().newLine(msg: "Evaluating prerequisite flag '\(flagKey)':")
        
        let evalResult = evalSetting(setting: prereq, key: flagKey, user: user, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
        cycleTracker.removeLast()
        
        switch evalResult {
        case .success(let val, _, _, _):
            let match = needsTrue == (Utils.anyEq(a: compVal, b: val))
            evalLogger?.newLine(msg: "Prerequisite flag evaluation result: '\(val)'.")
                .newLine(msg: "Condition (").append(value: cond).append(value: ") evaluates to ").append(value: "\(match ? "true" : "false").")
                .decIndent()
                .newLine(msg: ")")
            return .success(match)
        case .error(let err):
            return .fatal(err)
        }
    }
    
    private func evalUserCondition(cond: UserCondition, key: String, user: ConfigCatUser, salt: String?, ctxSalt: String) -> EvalConditionResult {
        guard let comparisonAttribute = cond.comparisonAttribute else {
            return .fatal("Comparison attribute is missing")
        }
        guard let userAnyVal = user.attribute(for: comparisonAttribute) else {
            return .attributeMissing(cond)
        }
        switch cond.comparator {
        case .eq, .notEq, .eqHashed, .notEqHashed:
            guard let compVal = cond.stringValue else {
                return .compValueInvalid(nil)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            guard let salt = salt else {
                return .fatal(RolloutEvaluator.saltMissingMessage)
            }
            return evalTextEq(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .oneOf, .notOneOf, .oneOfHashed, .notOneOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            guard let salt = salt else {
                return .fatal(RolloutEvaluator.saltMissingMessage)
            }
            return evalOneOf(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .startsWithAnyOf, .startsWithAnyOfHashed, .notStartsWithAnyOf, .notStartsWithAnyOfHashed, .endsWithAnyOf, .endsWithAnyOfHashed, .notEndsWithAnyOf, .notEndsWithAnyOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            guard let salt = salt else {
                return .fatal(RolloutEvaluator.saltMissingMessage)
            }
            return evalStartsEndsWith(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .contains, .notContains:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            return evalContains(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .oneOfSemver, .notOneOfSemver:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userVal = asSemver(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid semantic version", cond)
            }
            return evalSemverIsOneOf(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
        
        case .lessSemver, .lessEqSemver, .greaterSemver, .greaterEqSemver:
            guard let compVal = cond.stringValue else {
                return .compValueInvalid(nil)
            }
            guard let userVal = asSemver(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid semantic version", cond)
            }
            return evalSemverCompare(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .eqNum, .notEqNum, .lessNum, .lessEqNum, .greaterNum, .greaterEqNum:
            guard let compVal = cond.doubleValue else {
                return .compValueInvalid(nil)
            }
            guard let userVal = asDouble(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid decimal number", cond)
            }
            return evalNumberCompare(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .beforeDateTime, .afterDateTime:
            guard let compVal = cond.doubleValue else {
                return .compValueInvalid(nil)
            }
            guard let userVal = asDateDouble(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)", cond)
            }
            return evalDateTime(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .arrayContainsAnyOf, .arrayNotContainsAnyOf, .arrayContainsAnyOfHashed, .arrayNotContainsAnyOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userVal = asSlice(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid string array", cond)
            }
            guard let salt = salt else {
                return .fatal(RolloutEvaluator.saltMissingMessage)
            }
            return evalArrayContains(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
        default:
            return .fatal("Comparison operator is invalid")
        }
    }

    private func evalTextEq(comparisonValue: String, userValue: String, comp: UserComparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .eqHashed : comp == .eq
        return .success((comparisonValue == (comp.isSensitive ? userValue.sha256hex(salt: salt, contextSalt: ctxSalt) : userValue)) == needsTrue)
    }
    
    private func evalOneOf(comparisonValue: [String], userValue: String, comp: UserComparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .oneOfHashed : comp == .oneOf
        let userVal = comp.isSensitive ? userValue.sha256hex(salt: salt, contextSalt: ctxSalt) : userValue
        for value in comparisonValue {
            if value == userVal {
                return .success(needsTrue)
            }
        }
        return .success(!needsTrue)
    }
    
    private func evalStartsEndsWith(comparisonValue: [String], userValue: String, comp: UserComparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isStartsWith ? comp.isSensitive ? comp == .startsWithAnyOfHashed : comp == .startsWithAnyOf :
        comp.isSensitive ? comp == .endsWithAnyOfHashed : comp == .endsWithAnyOf
        let userValData = Data(userValue.utf8)
        for value in comparisonValue {
            if comp.isSensitive {
                let parts = value.components(separatedBy: "_")
                if parts.count < 2 || parts[1].isEmpty {
                    return .fatal("Comparison value is missing or invalid")
                }
                guard let length = Int(parts[0].trimmingCharacters(in: .whitespaces)), length > 0 else {
                    return .fatal("Comparison value is missing or invalid")
                }
                if length > userValData.count {
                    continue
                }
                let chunk = comp.isStartsWith ? userValData[..<length] : userValData[(userValData.count - length)...]
                
                if chunk.sha256hex(salt: salt, contextSalt: ctxSalt) == parts[1] {
                    return .success(needsTrue)
                }
            } else {
                if comp.isStartsWith ? userValue.hasPrefix(value) : userValue.hasSuffix(value) {
                    return .success(needsTrue)
                }
            }
        }
        return .success(!needsTrue)
    }
    
    private func evalContains(comparisonValue: [String], userValue: String, comp: UserComparator) -> EvalConditionResult {
        let needsTrue = comp == .contains
        for value in comparisonValue {
            if userValue.contains(value) {
                return .success(needsTrue)
            }
        }
        return .success(!needsTrue)
    }
    
    private func evalSemverIsOneOf(comparisonValue: [String], userValue: Version, comp: UserComparator) -> EvalConditionResult {
        let needsTrue = comp == .oneOfSemver
        var matched = false
        for value in comparisonValue {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            guard let compVer = trimmed.toVersion() else {
                // NOTE: Previous versions of the evaluation algorithm ignored invalid comparison values.
                // We keep this behavior for backward compatibility.
                return .success(false)
            }
            if userValue == compVer {
                matched = true
            }
        }
        return .success(matched == needsTrue)
    }
    
    private func evalSemverCompare(comparisonValue: String, userValue: Version, comp: UserComparator) -> EvalConditionResult {
        guard let compVer = comparisonValue.toVersion() else {
            // NOTE: Previous versions of the evaluation algorithm ignored invalid comparison values.
            // We keep this behavior for backward compatibility.
            return .success(false)
        }
        switch comp {
        case .greaterSemver:
            return .success(userValue > compVer)
        case .greaterEqSemver:
            return .success(userValue >= compVer)
        case .lessSemver:
            return .success(userValue < compVer)
        case .lessEqSemver:
            return .success(userValue <= compVer)
        default:
            return .fatal("wrong semver comparator") // shouldn't happen
        }
    }
    
    private func evalNumberCompare(comparisonValue: Double, userValue: Double, comp: UserComparator) -> EvalConditionResult {
        switch comp {
        case .eqNum:
            return .success(userValue == comparisonValue)
        case .notEqNum:
            return .success(userValue != comparisonValue)
        case .greaterNum:
            return .success(userValue > comparisonValue)
        case .greaterEqNum:
            return .success(userValue >= comparisonValue)
        case .lessNum:
            return .success(userValue < comparisonValue)
        case .lessEqNum:
            return .success(userValue <= comparisonValue)
        default:
            return .fatal("wrong number comparator") // shouldn't happen
        }
    }
    
    private func evalDateTime(comparisonValue: Double, userValue: Double, comp: UserComparator) -> EvalConditionResult {
        return comp == .beforeDateTime ? .success(userValue < comparisonValue) : .success(userValue > comparisonValue)
    }
    
    private func evalArrayContains(comparisonValue: [String], userValue: [String], comp: UserComparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .arrayContainsAnyOfHashed : comp == .arrayContainsAnyOf
        for userItem in userValue {
            let usrVal = comp.isSensitive ? userItem.sha256hex(salt: salt, contextSalt: ctxSalt) : userItem
            for value in comparisonValue {
                if usrVal == value {
                    return .success(needsTrue)
                }
            }
        }
        return .success(!needsTrue)
    }
    
    private func asString(value: Any) -> (String, Bool) {
        switch value {
        case let val as String:
            return (val, false)
        case let val as [String]:
            return (arrToJson(arr: val), true)
        case let val as Int:
            return (val.description, true)
        case let val as Int8:
            return (val.description, true)
        case let val as Int16:
            return (val.description, true)
        case let val as Int32:
            return (val.description, true)
        case let val as Int64:
            return (val.description, true)
        case let val as UInt:
            return (val.description, true)
        case let val as UInt8:
            return (val.description, true)
        case let val as UInt16:
            return (val.description, true)
        case let val as UInt32:
            return (val.description, true)
        case let val as UInt64:
            return (val.description, true)
        case let val as Float:
            return val.isNaN ? ("NaN", true) : val.isInfinite ? (val < 0 ? "-Infinity" : "Infinity", true) : (val.description, true)
        case let val as Float32:
            return val.isNaN ? ("NaN", true) : val.isInfinite ? (val < 0 ? "-Infinity" : "Infinity", true) : (val.description, true)
        case let val as Float64:
            return val.isNaN ? ("NaN", true) : val.isInfinite ? (val < 0 ? "-Infinity" : "Infinity", true) : (val.description, true)
        case let val as Double:
            return val.isNaN ? ("NaN", true) : val.isInfinite ? (val < 0 ? "-Infinity" : "Infinity", true) : (val.description, true)
        case let val as Date:
            return (val.timeIntervalSince1970.description, true)
        default:
            return ("\(value)", true)
        }
    }
    
    private func asDouble(value: Any) -> Double? {
        switch value {
        case let val as String:
            let stringVal = val.trimmingCharacters(in: .whitespacesAndNewlines)
            switch stringVal {
            case "Infinity", "+Infinity":
                return Double.infinity
            case "-Infinity":
                return -Double.infinity
            case "NaN":
                return Double.nan
            default:
                return Double(stringVal.replacingOccurrences(of: ",", with: "."))
            }
        case let val as Int:
            return Double(val)
        case let val as Int8:
            return Double(val)
        case let val as Int16:
            return Double(val)
        case let val as Int32:
            return Double(val)
        case let val as Int64:
            return Double(val)
        case let val as UInt:
            return Double(val)
        case let val as UInt8:
            return Double(val)
        case let val as UInt16:
            return Double(val)
        case let val as UInt32:
            return Double(val)
        case let val as UInt64:
            return Double(val)
        case let val as Float:
            return Double(val)
        case let val as Float32:
            return Double(val)
        case let val as Float64:
            return Double(val)
        case let val as Double:
            return Double(val)
        default:
            return nil
        }
    }
    
    private func asDateDouble(value: Any) -> Double? {
        if case let val as Date = value {
            return val.timeIntervalSince1970
        }
        return asDouble(value: value)
    }
    
    private func asSemver(value: Any) -> Version? {
        if case let val as String = value {
            return val.toVersion()
        }
        return nil
    }
    
    private func asSlice(value: Any) -> [String]? {
        switch value {
        case let val as [String]:
            return val
        case let val as String:
            return decodeSliceFromJson(json: val)
        default:
            return nil
        }
    }
    
    private func decodeSliceFromJson(json: String) -> [String]? {
        do {
            guard let data = json.data(using: .utf8) else {
                return nil
            }
            guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String] else {
                return nil
            }
            return result
        } catch {
            return nil
        }
    }
    
    private func arrToJson(arr: [String]) -> String {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(arr)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func logConverted(cond: UserCondition, key: String, attrValue: String) {
        log.warning(eventId: 3005, message: "Evaluation of condition (\(cond)) for setting '\(key)' may not produce the expected result (the User.\(cond.unwrappedComparisonAttribute) attribute is not a string value, thus it was automatically converted to the string value '\(attrValue)'). Please make sure that using a non-string value was intended.")
    }
    
    private func logUserObjectMissing(key: String) {
        log.warning(eventId: 3001, message: "Cannot evaluate targeting rules and % options for setting '\(key)' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()`/`getValueDetails()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeMissing(key:String, cond: UserCondition) {
        log.warning(eventId: 3003, message: "Cannot evaluate condition (\(cond)) for setting '\(key)' (the User.\(cond.unwrappedComparisonAttribute) attribute is missing). You should set the User.\(cond.unwrappedComparisonAttribute) attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeMissing(key:String, attr: String) {
        log.warning(eventId: 3003, message: "Cannot evaluate % options for setting '\(key)' (the User.\(attr) attribute is missing). You should set the User.\(attr) attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeInvalid(key:String, reason: String, cond: UserCondition) {
        log.warning(eventId: 3004, message: "Cannot evaluate condition (\(cond)) for setting '\(key)' (\(reason)). Please check the User.\(cond.unwrappedComparisonAttribute) attribute and make sure that its value corresponds to the comparison operator.")
    }
}

internal extension String {
    var sha1hex: String {
        return Data(self.utf8).digestSHA1.hexString
    }
    
    func sha256hex(salt: String, contextSalt: String) -> String {
        return Data((self + salt + contextSalt).utf8).digestSHA256.hexString
    }
    
    func toVersion() -> Version? {
        if let semver = Version(self.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Version(semver.major, semver.minor, semver.patch, pre: semver.prereleaseIdentifiers)
        }
        return nil
    }
}

internal extension Data {
    func sha256hex(salt: String, contextSalt: String) -> String {
        var copy = Data(self)
        copy.append(Data((salt + contextSalt).utf8))
        return copy.digestSHA256.hexString
    }
    
    var digestSHA1: Data {
        var bytes: [UInt8] = Array(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(count), &bytes)
        }
        return Data(_: bytes)
    }
    
    var digestSHA256: Data {
        var bytes: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(count), &bytes)
        }
        return Data(_: bytes)
    }

    var hexString: String {
        map {
            String(format: "%02x", UInt8($0))
        }.joined()
    }
}
