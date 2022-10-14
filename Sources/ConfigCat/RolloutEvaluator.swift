import Foundation
import CommonCrypto
import os.log

#if SWIFT_PACKAGE
import Version
#endif

class RolloutEvaluator {
    private static let comparatorTexts = [
        "IS ONE OF",
        "IS NOT ONE OF",
        "CONTAINS",
        "DOES NOT CONTAIN",
        "IS ONE OF (SemVer)",
        "IS NOT ONE OF (SemVer)",
        "< (SemVer)",
        "<= (SemVer)",
        "> (SemVer)",
        ">= (SemVer)",
        "= (Number)",
        "<> (Number)",
        "< (Number)",
        "<= (Number)",
        "> (Number)",
        ">= (Number",
        "IS ONE OF (Sensitive)",
        "IS NOT ONE OF (Sensitive)",
    ]
    private let log: Logger;


    init(logger: Logger) {
        log = logger
    }


    func evaluate(setting: Setting, key: String, user: ConfigCatUser?) -> (value: Any, variationId: String?, evaluateLog: String?, rollout: RolloutRule?, percentage: PercentageRule?) {
        guard let user = user else {
            if setting.rolloutRules.count > 0 || setting.percentageItems.count > 0 {
                log.warning(message: String(format:
                """
                Evaluating getValue(%@). UserObject missing!
                You should pass a UserObject to getValue(),
                in order to make targeting work properly.
                Read more: https://configcat.com/docs/advanced/user-object/
                """, key))
            }

            return (setting.value, setting.variationId, nil, nil, nil)
        }

        var evaluateLog = String(format: "Evaluating getValue(%@).\nUser object: %@.", key, user)

        for rule in setting.rolloutRules {
            let comparisonAttribute = rule.comparisonAttribute
            let comparisonValue = rule.comparisonValue
            let comparator = rule.comparator

            if let userValue = user.getAttribute(for: comparisonAttribute) {
                if comparisonValue.isEmpty || userValue.isEmpty {
                    evaluateLog += "\n" + formatNoMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue)
                    continue
                }

                let ruleValue = rule.value
                let ruleVariationId = rule.variationId

                switch comparator {
                        // IS ONE OF
                case 0:
                    let split = comparisonValue.components(separatedBy: ",")
                            .map { val in
                                val.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            }

                    if split.contains(userValue) {
                        let returnValue = ruleValue
                        evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                        return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                    }
                        // IS NOT ONE OF
                case 1:
                    let split = comparisonValue.components(separatedBy: ",")
                            .map { val in
                                val.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            }

                    if !split.contains(userValue) {
                        let returnValue = ruleValue
                        evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                        return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                    }
                        // CONTAINS
                case 2:
                    if userValue.contains(comparisonValue) {
                        let returnValue = ruleValue
                        evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                        return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                    }
                        // DOES NOT CONTAIN
                case 3:
                    if !userValue.contains(comparisonValue) {
                        let returnValue = ruleValue
                        evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                        return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                    }
                        // IS ONE OF (Semantic version), IS NOT ONE OF (Semantic version)
                case 4...5:
                    let split = comparisonValue.components(separatedBy: ",")
                            .map { val in
                                val.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            }
                            .filter { val -> Bool in
                                !val.isEmpty
                            }

                    // The rule will be ignored if we found an invalid semantic version
                    if let invalidValue = (split.first { val -> Bool in
                        Version(val) == nil
                    }) {
                        let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                error: "Invalid semantic version: \(invalidValue)")
                        log.warning(message: message)
                        evaluateLog += "\n" + message
                        continue
                    }
                    if Version(userValue) == nil {
                        let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                error: "Invalid semantic version: \(userValue)")
                        log.warning(message: message)
                        evaluateLog += "\n" + message
                        continue
                    }

                    if comparator == 4 { // IS ONE OF
                        if Version(userValue) == nil {
                            let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                    error: "Invalid semantic version: \(userValue)")
                            log.warning(message: message)
                            evaluateLog += "\n" + message
                            continue
                        }

                        if let userValueVersion = Version(userValue) {
                            if (split.first { val -> Bool in
                                userValueVersion == Version(val)
                            } != nil) {
                                let returnValue = ruleValue
                                evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                                return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                            }
                        }
                    } else { // IS NOT ONE OF
                        if Version(userValue) == nil {
                            let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                    error: "Invalid semantic version: \(userValue)")
                            log.warning(message: message)
                            evaluateLog += "\n" + message
                            continue
                        }

                        if let userValueVersion = Version(userValue) {
                            if let invalidValue = (split.first { val -> Bool in
                                userValueVersion == Version(val)
                            }) {
                                let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                        error: "Invalid semantic version: \(invalidValue)")
                                log.warning(message: message)
                                evaluateLog += "\n" + message
                                continue
                            }

                            let returnValue = ruleValue
                            evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                            return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                        }
                    }
                        // LESS THAN, LESS THAN OR EQUALS TO, GREATER THAN, GREATER THAN OR EQUALS TO (Semantic version)
                case 6...9:
                    let comparison = comparisonValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if Version(userValue) == nil {
                        let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                error: "Invalid semantic version: \(userValue)")
                        log.warning(message: message)
                        evaluateLog += "\n" + message
                        continue
                    }

                    if Version(comparison) == nil {
                        let message = formatValidationErrorRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue,
                                error: "Invalid semantic version: \(comparison)")
                        log.warning(message: message)
                        evaluateLog += "\n" + message
                        continue
                    }
                    if let userValueVersion = Version(userValue),
                       let comparisonValueVersion = Version(comparison) {
                        let userValueVersionWithoutMetadata = Version(major: userValueVersion.major,
                                minor: userValueVersion.minor,
                                patch: userValueVersion.patch,
                                prereleaseIdentifiers: userValueVersion.prereleaseIdentifiers)
                        let comparisonValueVersionWithoutMetadata = Version(major: comparisonValueVersion.major,
                                minor: comparisonValueVersion.minor,
                                patch: comparisonValueVersion.patch,
                                prereleaseIdentifiers: comparisonValueVersion.prereleaseIdentifiers)
                        if (comparator == 6 && userValueVersionWithoutMetadata < comparisonValueVersionWithoutMetadata)
                                   || (comparator == 7 && userValueVersionWithoutMetadata <= comparisonValueVersionWithoutMetadata)
                                   || (comparator == 8 && userValueVersionWithoutMetadata > comparisonValueVersionWithoutMetadata)
                                   || (comparator == 9 && userValueVersionWithoutMetadata >= comparisonValueVersionWithoutMetadata) {
                            let returnValue = ruleValue
                            evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                            return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                        }
                    }
                case 10...15:
                    if let userValueFloat = Float(userValue.replacingOccurrences(of: ",", with: ".")),
                       let comparisonValueFloat = Float(comparisonValue.replacingOccurrences(of: ",", with: ".")) {
                        if (comparator == 10 && userValueFloat == comparisonValueFloat)
                                   || (comparator == 11 && userValueFloat != comparisonValueFloat)
                                   || (comparator == 12 && userValueFloat < comparisonValueFloat)
                                   || (comparator == 13 && userValueFloat <= comparisonValueFloat)
                                   || (comparator == 14 && userValueFloat > comparisonValueFloat)
                                   || (comparator == 15 && userValueFloat >= comparisonValueFloat) {
                            let returnValue = ruleValue
                            evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                            return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                        }
                    }
                        // IS ONE OF (Sensitive)
                case 16:
                    let split = comparisonValue.components(separatedBy: ",")
                            .map { val in
                                val.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            }

                    if let userValueHash = userValue.sha1hex {
                        if split.contains(userValueHash) {
                            let returnValue = ruleValue
                            evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValueHash, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                            return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                        }
                    }
                        // IS NOT ONE OF (Sensitive)
                case 17:
                    let split = comparisonValue.components(separatedBy: ",")
                            .map { val in
                                val.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            }

                    if let userValueHash = userValue.sha1hex {
                        if !split.contains(userValueHash) {
                            let returnValue = ruleValue
                            evaluateLog += "\n" + formatMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValueHash, comparator: comparator, comparisonValue: comparisonValue, value: returnValue)
                            return (returnValue, ruleVariationId, evaluateLog, rule, nil)
                        }
                    }
                default:
                    continue
                }

                evaluateLog += "\n" + formatNoMatchRule(comparisonAttribute: comparisonAttribute, userValue: userValue, comparator: comparator, comparisonValue: comparisonValue)
            }
        }

        if (setting.percentageItems.count > 0) {
            let hashCandidate = key + user.identifier
            if let hash = hashCandidate.sha1hex?.prefix(7) {
                let hashString = String(hash)
                if let num = Int(hashString, radix: 16) {
                    let scaled = num % 100

                    var bucket = 0
                    for rule in setting.percentageItems {
                        bucket += rule.percentage
                        if scaled < bucket {
                            evaluateLog += "\n" + String(format: "Evaluating %@ options. Returning %@", "%", rule.value as? String ?? "")
                            return (rule.value, rule.variationId, evaluateLog, nil, rule)
                        }
                    }
                }
            }
        }

        evaluateLog += "\n" + String(format: "Returning %@", setting.value as? String ?? "")
        return (setting.value, setting.variationId, evaluateLog, nil, nil)
    }

    private func formatMatchRule(comparisonAttribute: String, userValue: String, comparator: Int, comparisonValue: String, value: Any) -> String {
        let format = String(format: "Evaluating rule: [%@:%@] [%@] [%@] => match, returning: ",
                comparisonAttribute, userValue, RolloutEvaluator.comparatorTexts[comparator], comparisonValue)

        return format + "\(value)"
    }

    private func formatNoMatchRule(comparisonAttribute: String, userValue: String, comparator: Int, comparisonValue: String) -> String {
        String(format: "Evaluating rule: [%@:%@] [%@] [%@] => no match",
                comparisonAttribute, userValue, RolloutEvaluator.comparatorTexts[comparator], comparisonValue)
    }

    private func formatValidationErrorRule(comparisonAttribute: String, userValue: String, comparator: Int, comparisonValue: String, error: String) -> String {
        String(format: "Evaluating rule: [%@:%@] [%@] [%@] => SKIP rule. Validation error: %@",
                comparisonAttribute, userValue, RolloutEvaluator.comparatorTexts[comparator], comparisonValue, error)
    }
}

internal extension String {
    var sha1hex: String? {
        if let utf8Data = data(using: .utf8, allowLossyConversion: false) {
            return utf8Data.digestSHA1.hexString
        }
        return nil
    }
}

internal extension Data {
    var digestSHA1: Data {
        var bytes: [UInt8] = Array(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(count), &bytes)
        }
        return Data(_: bytes)
    }

    var hexString: String {
        map {
            String(format: "%02x", UInt8($0))
        }
                .joined()
    }
}
