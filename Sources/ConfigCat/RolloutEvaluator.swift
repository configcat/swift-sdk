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
        switch self {
        case .success(_):
            return true
        default:
            return false
        }
    }
    
    var isMatch: Bool {
        switch self {
        case .success(let match):
            return match
        default:
            return false
        }
    }
    
    var err: String {
        switch self {
        case .success(_):
            return ""
        case .noUser:
            return "cannot evaluate, User Object is missing"
        case .attributeMissing(let cond):
            return "cannot evaluate, the User.\(cond.comparisonAttribute) attribute is missing"
        case .attributeInvalid(let reason, let cond):
            return "cannot evaluate, the User.\(cond.comparisonAttribute) attribute is invalid (\(reason))"
        case .compValueInvalid(let err):
            return "cannot evaluate, (\(err ?? "comparison value is missing or invalid"))"
        case .fatal(let err):
            return "cannot evaluate (\(err))"
        }
    }
    
    var isAttributeMissing: Bool {
        switch self {
        case .attributeMissing(_):
            return true
        default:
            return false
        }
    }
}

enum EvalResult {
    case success(Any, String?, TargetingRule?, PercentageOption?)
    case error(String)
}

class RolloutEvaluator {
    static let ruleIgnoredMessage = "The current targeting rule is ignored and the evaluation continues with the next rule."
    static let invalidValueText = "<invalid value>"
    private let log: InternalLogger;

    init(logger: InternalLogger) {
        log = logger
    }

    func evaluate(setting: Setting, key: String, user: ConfigCatUser?, settings: [String: Setting], defaultValue: Any? = nil) -> EvalResult {
        let evalLogger = log.enabled(level: .info) ? EvaluationLogger() : nil
        var cycleTracker: [String] = []
        
        evalLogger?.append(value: "Evaluating '\(key)'")
        if let usr = user {
            evalLogger?.append(value: " for User '\(usr.description)'")
        }
        evalLogger?.incIndent()
        
        let result = evalSetting(setting: setting, key: key, user: user, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
        switch result {
        case .success(let val, _, _, _):
            evalLogger?.newLine(msg: "Returning '\(val)'.")
        default:
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
                    if !rule.servedValue.value.isEmpty {
                        return evalResult(value: rule.servedValue.value, variationId: rule.servedValue.variationId, rule: rule, opt: nil)
                    }
                    evalLogger?.incIndent()
                    if !rule.percentageOptions.isEmpty {
                        if let usr = user {
                            if let matchedOption = evalPercentageOptions(opts: rule.percentageOptions, user: usr, key: key, percentageAttr: setting.percentageAttribute, evalLogger: evalLogger) {
                                evalLogger?.decIndent()
                                return evalResult(value: matchedOption.servedValue, variationId: matchedOption.variationId, rule: rule, opt: matchedOption)
                            }
                        } else {
                            if !userMissingLogged {
                                logUserObjectMissing(key: key)
                                userMissingLogged = true
                            }
                            evalLogger?.newLine(msg: "Skipping % options because the User Object is missing.")
                        }
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
                if let matchedOption = evalPercentageOptions(opts: setting.percentageOptions, user: usr, key: key, percentageAttr: setting.percentageAttribute, evalLogger: evalLogger) {
                    return evalResult(value: matchedOption.servedValue, variationId: matchedOption.variationId, rule: nil, opt: matchedOption)
                }
            } else {
                if !userMissingLogged {
                    logUserObjectMissing(key: key)
                    userMissingLogged = true
                }
                evalLogger?.newLine(msg: "Skipping % options because the User Object is missing.")
            }
        }
        return evalResult(value: setting.value, variationId: setting.variationId, rule: nil, opt: nil)
    }
    
    private func evalResult(value: SettingValue, variationId: String?, rule: TargetingRule?, opt: PercentageOption?) -> EvalResult {
        if let val = value.val {
            return .success(val, variationId, rule, opt)
        } else if let invalid = value.invalidValue {
            return .error("Setting value '\(invalid)' is of an unsupported type (\(type(of: invalid))")
        } else {
            return .error("Setting value is missing or invalid")
        }
    }
    
    private func evalPercentageOptions(opts: [PercentageOption], user: ConfigCatUser, key: String, percentageAttr: String, evalLogger: EvaluationLogger?) -> PercentageOption? {
        let percAttr = percentageAttr == "" ? "Identifier" : percentageAttr
        guard let attrVal = user.attribute(for: percAttr) else {
            logAttributeMissing(key: key, attr: percAttr)
            evalLogger?.newLine(msg: "Skipping % options because the User.\(percAttr) attribute is missing.")
            return nil
        }
        evalLogger?.newLine(msg: "Evaluating % options based on the User.\(percAttr) attribute:")
        let (stringAttrVal, _) = asString(value: attrVal)
        let hashCandidate = key + stringAttrVal
        let hash = hashCandidate.sha1hex.prefix(7)
        let hashString = String(hash)
        if let num = Int(hashString, radix: 16) {
            let scaled = num % 100
            evalLogger?.newLine(msg: "- Computing hash in the [0..99] range from User.\(percAttr) => \(scaled) (this value is sticky and consistent across all SDKs)")
            var bucket = 0
            for (index, opt) in opts.enumerated() {
                bucket += opt.percentage
                if scaled < bucket {
                    evalLogger?.newLine(msg: "- Hash value \(scaled) selects % option \(index + 1) (\(opt.percentage)%), '\(opt.servedValue.val ?? RolloutEvaluator.invalidValueText)'.")
                    return opt
                }
            }
        }
        return nil
    }
    
    private func evalConditions(targetingRule: TargetingRule, key: String, user: ConfigCatUser?, salt: String, ctxSalt: String, evalLogger: EvaluationLogger?, settings: [String: Setting], cycleTracker: inout [String]) -> EvalConditionResult {
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
                    condResult = evalUserCondition(cond: userCondition, key: key, user: usr, salt: salt, ctxSalt: ctxSalt, evalLogger: evalLogger)
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
                condResult = evalPrerequisiteCondition(cond: prerequisiteFlagCondition, key: key, user: user, salt: salt, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
                newLineBeforeThen = true
            }
            
            if targetingRule.conditions.count > 1 {
                evalLogger?.append(value: " => ").append(value: condResult.isMatch ? "true" : "false").append(value: condResult.isMatch ? "" : ", skipping the remaining AND conditions")
            }
            
            evalLogger?.decIndent()
            
            switch condResult {
            case .success(let match):
                matched = match
            default:
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
    
    private func evalSegmentCondition(cond: SegmentCondition, key: String, salt: String, user: ConfigCatUser, evalLogger: EvaluationLogger?) -> EvalConditionResult {
        guard let name = cond.segment?.name else {
            return .fatal("Segment name is missing")
        }
        guard let userConditions = cond.segment?.conditions else {
            return .fatal("Segment reference is invalid")
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
            result = evalUserCondition(cond: userCondition, key: key, user: user, salt: salt, ctxSalt: name, evalLogger: evalLogger)
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
        switch result {
        case .success(let match):
            return .success(match == needsTrue)
        default:
            return result
        }
    }
    
    private func evalPrerequisiteCondition(cond: PrerequisiteFlagCondition, key: String, user: ConfigCatUser?, salt: String, evalLogger: EvaluationLogger?, settings: [String: Setting], cycleTracker: inout [String]) -> EvalConditionResult {
        evalLogger?.append(value: cond)
        guard let prereq = settings[cond.flagKey] else {
            return .fatal("Prerequisite flag is missing or invalid")
        }
        if !cond.flagValue.isValid {
            return .fatal("Prerequisite flag value is invalid")
        }
        if prereq.settingType != .unknown && prereq.settingType != cond.flagValue.settingType {
            return .fatal("Type mismatch between comparison value '\(cond.flagValue.val ?? "")' and prerequisite flag '\(cond.flagKey)'.")
        }
        cycleTracker.append(key)
        if cycleTracker.contains(cond.flagKey) {
            cycleTracker.append(cond.flagKey)
            let output = cycleTracker.map { c in
                return "'"+c+"'"
            }.joined(separator: " -> ")
            return .fatal("Circular dependency detected between the following depending flags: [\(output)].")
        }
        let needsTrue = cond.prerequisiteComparator == .eq
        
        evalLogger?.newLine(msg: "(").incIndent().newLine(msg: "Evaluating prerequisite flag '\(cond.flagKey)':")
        
        let evalResult = evalSetting(setting: prereq, key: cond.flagKey, user: user, evalLogger: evalLogger, settings: settings, cycleTracker: &cycleTracker)
        cycleTracker.removeLast()
        
        switch evalResult {
        case .success(let val, _, _, _):
            let match = needsTrue == (cond.flagValue.eq(to: val))
            evalLogger?.newLine(msg: "Prerequisite flag evaluation result: '\(val)'.")
                .newLine(msg: "Condition (").append(value: cond).append(value: ") evaluates to ").append(value: "\(match ? "true" : "false").")
                .decIndent()
                .newLine(msg: ")")
            return .success(match)
        case .error(let err):
            return .fatal(err)
        }
    }
    
    private func evalUserCondition(cond: UserCondition, key: String, user: ConfigCatUser, salt: String, ctxSalt: String, evalLogger: EvaluationLogger?) -> EvalConditionResult {
        switch cond.comparator {
        case .eq, .notEq, .eqHashed, .notEqHashed:
            guard let compVal = cond.stringValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            return evalTextEq(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .oneOf, .notOneOf, .oneOfHashed, .notOneOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            return evalOneOf(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .startsWithAnyOf, .startsWithAnyOfHashed, .notStartsWithAnyOf, .notStartsWithAnyOfHashed, .endsWithAnyOf, .endsWithAnyOfHashed, .notEndsWithAnyOf, .notEndsWithAnyOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            let (userVal, converted) = asString(value: userAnyVal)
            if converted {
                logConverted(cond: cond, key: key, attrValue: userVal)
            }
            return evalStartsEndsWith(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
            
        case .contains, .notContains:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
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
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            guard let userVal = asSemver(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid semantic version", cond)
            }
            return evalSemverIsOneOf(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
        
        case .lessSemver, .lessEqSemver, .greaterSemver, .greaterEqSemver:
            guard let compVal = cond.stringValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            guard let userVal = asSemver(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid semantic version", cond)
            }
            return evalSemverCompare(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .eqNum, .notEqNum, .lessNum, .lessEqNum, .greaterNum, .greaterEqNum:
            guard let compVal = cond.doubleValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            guard let userVal = asDouble(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid decimal number", cond)
            }
            return evalNumberCompare(comparisonValue: compVal, userValue: userVal, comp: cond.comparator)
            
        case .beforeDateTime, .afterDateTime:
            guard let compVal = cond.doubleValue else {
                return .compValueInvalid(nil)
            }
            let compDate = Date(timeIntervalSince1970: compVal)
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            guard let userVal = asDate(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)", cond)
            }
            return evalDateTime(comparisonValue: compDate, userValue: userVal, comp: cond.comparator)
            
        case .arrayContainsAnyOf, .arrayNotContainsAnyOf, .arrayContainsAnyOfHashed, .arrayNotContainsAnyOfHashed:
            guard let compVal = cond.stringArrayValue else {
                return .compValueInvalid(nil)
            }
            guard let userAnyVal = user.attribute(for: cond.comparisonAttribute) else {
                return .attributeMissing(cond)
            }
            guard let userVal = asSlice(value: userAnyVal) else {
                return .attributeInvalid("'\(userAnyVal)' is not a valid string array", cond)
            }
            return evalArrayContains(comparisonValue: compVal, userValue: userVal, comp: cond.comparator, salt: salt, ctxSalt: ctxSalt)
        }
    }

    private func evalTextEq(comparisonValue: String, userValue: String, comp: Comparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .eqHashed : comp == .eq
        return .success((comparisonValue == (comp.isSensitive ? userValue.sha256hex(salt: salt, contextSalt: ctxSalt) : userValue)) == needsTrue)
    }
    
    private func evalOneOf(comparisonValue: [String], userValue: String, comp: Comparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .oneOfHashed : comp == .oneOf
        for value in comparisonValue {
            if value == (comp.isSensitive ? userValue.sha256hex(salt: salt, contextSalt: ctxSalt) : userValue) {
                return .success(needsTrue)
            }
        }
        return .success(!needsTrue)
    }
    
    private func evalStartsEndsWith(comparisonValue: [String], userValue: String, comp: Comparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isStartsWith ? comp.isSensitive ? comp == .startsWithAnyOfHashed : comp == .startsWithAnyOf :
        comp.isSensitive ? comp == .endsWithAnyOfHashed : comp == .endsWithAnyOf
        let userValData = Data(userValue.utf8)
        for value in comparisonValue {
            if comp.isSensitive {
                let parts = value.components(separatedBy: "_")
                if parts.isEmpty {
                    return .fatal("Comparison value is missing or invalid")
                }
                guard let length = Int(parts[0]) else {
                    return .fatal("Could not parse the length part of the comparison value")
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
    
    private func evalContains(comparisonValue: [String], userValue: String, comp: Comparator) -> EvalConditionResult {
        let needsTrue = comp == .contains
        for value in comparisonValue {
            if userValue.contains(value) {
                return .success(needsTrue)
            }
        }
        return .success(!needsTrue)
    }
    
    private func evalSemverIsOneOf(comparisonValue: [String], userValue: Version, comp: Comparator) -> EvalConditionResult {
        let needsTrue = comp == .oneOfSemver
        var matched = false
        for value in comparisonValue {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            guard let compVer = trimmed.toVersion() else {
                return .compValueInvalid("'\(trimmed)' is not a valid semantic version")
            }
            if userValue == compVer {
                matched = true
            }
        }
        return .success(matched == needsTrue)
    }
    
    private func evalSemverCompare(comparisonValue: String, userValue: Version, comp: Comparator) -> EvalConditionResult {
        guard let compVer = comparisonValue.toVersion() else {
            return .compValueInvalid("'\(comparisonValue)' is not a valid semantic version")
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
    
    private func evalNumberCompare(comparisonValue: Double, userValue: Double, comp: Comparator) -> EvalConditionResult {
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
    
    private func evalDateTime(comparisonValue: Date, userValue: Date, comp: Comparator) -> EvalConditionResult {
        return comp == .beforeDateTime ? .success(userValue < comparisonValue) : .success(userValue > comparisonValue)
    }
    
    private func evalArrayContains(comparisonValue: [String], userValue: [String], comp: Comparator, salt: String, ctxSalt: String) -> EvalConditionResult {
        let needsTrue = comp.isSensitive ? comp == .arrayContainsAnyOfHashed : comp == .arrayContainsAnyOf
        for value in comparisonValue {
            for userItem in userValue {
                let usrVal = comp.isSensitive ? userItem.sha256hex(salt: salt, contextSalt: ctxSalt) : userItem
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
            return ("", false)
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
    
    private func asDate(value: Any) -> Date? {
        switch value {
        case let val as Date:
            return val
        default:
            if let doubleVal = asDouble(value: value) {
                return Date(timeIntervalSince1970: doubleVal)
            }
            return nil
        }
    }
    
    private func asSemver(value: Any) -> Version? {
        switch value {
        case let val as String:
            return val.toVersion()
        default:
            return nil
        }
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
        log.warning(eventId: 3005, message: "Evaluation of condition (\(cond)) for setting '\(key)' may not produce the expected result (the User.\(cond.comparisonAttribute) attribute is not a string value, thus it was automatically converted to the string value '\(attrValue)'). Please make sure that using a non-string value was intended.")
    }
    
    private func logUserObjectMissing(key: String) {
        log.warning(eventId: 3001, message: "Cannot evaluate targeting rules and % options for setting '\(key)' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()`/`getValueDetails()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeMissing(key:String, cond: UserCondition) {
        log.warning(eventId: 3003, message: "Cannot evaluate condition (\(cond)) for setting '\(key)' (the User.\(cond.comparisonAttribute) attribute is missing). You should set the User.\(cond.comparisonAttribute) attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeMissing(key:String, attr: String) {
        log.warning(eventId: 3003, message: "Cannot evaluate % options for setting '\(key)' (the User.\(attr) attribute is missing). You should set the User.\(attr) attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/")
    }
    
    private func logAttributeInvalid(key:String, reason: String, cond: UserCondition) {
        log.warning(eventId: 3004, message: "Cannot evaluate condition (\(cond)) for setting '\(key)' (\(reason)). Please check the User.\(cond.comparisonAttribute) attribute and make sure that its value corresponds to the comparison operator.")
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
