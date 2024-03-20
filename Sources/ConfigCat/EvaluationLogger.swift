import Foundation

class EvaluationLogger {
    static let newLineChar: String = "\n"
    static let indentSeq: String = "  "
    
    var content: String = ""
    var indent: Int = 0
    
    @discardableResult
    func resetIndent() -> EvaluationLogger {
        indent = 0
        return self
    }
    
    @discardableResult
    func incIndent() -> EvaluationLogger {
        indent += 1
        return self
    }
    
    @discardableResult
    func decIndent() -> EvaluationLogger {
        indent -= 1
        return self
    }
    
    @discardableResult
    func newLine(msg: String? = nil) -> EvaluationLogger {
        content += EvaluationLogger.newLineChar + String(repeating: EvaluationLogger.indentSeq, count: indent)
        if let message = msg {
            content += message
        }
        return self
    }
    
    @discardableResult
    func append(value: Any) -> EvaluationLogger {
        content += "\(value)"
        return self
    }
    
    @discardableResult
    func appendThen(newLine: Bool, result: EvalConditionResult, targetingRule: TargetingRule) -> EvaluationLogger {
        self.incIndent()
        
        if newLine {
            self.newLine()
        } else {
            self.append(value: " ")
        }
        self.append(value: "THEN")
        
        if let val = targetingRule.servedValue?.value.anyValue {
            self.append(value: " '\(val)'")
        } else if !targetingRule.percentageOptions.isEmpty {
            self.append(value: " % options")
        }
            
        self.append(value: " => ").append(value: result.isSuccess ? result.isMatch ? "MATCH, applying rule" : "no match" : result.err)
        
        self.decIndent()
        
        return self
    }
}
