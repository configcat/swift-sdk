import os.log
import os
import Foundation

@objc public enum LogLevel: Int {
    case debug
    case info
    case warning
    case error
    case nolog
}

class Logger {
    public static let noLogger: Logger = Logger(level: .nolog)
    fileprivate static let log: OSLog = OSLog(subsystem: "com.configcat", category: "main")
    fileprivate let level: LogLevel
    
    public init(level: LogLevel) {
        self.level = level
    }
    
    public func debug(message: StaticString, _ args: CVarArg...) {
        self.log(message: message, currentLevel: .debug, args: args)
    }
    
    public func warning(message: StaticString, _ args: CVarArg...) {
        self.log(message: message, currentLevel: .warning, args: args)
    }
    
    public func info(message: StaticString, _ args: CVarArg...) {
        self.log(message: message, currentLevel: .info, args: args)
    }
    
    public func error(message: StaticString, _ args: CVarArg...) {
        self.log(message: message, currentLevel: .error, args: args)
    }
    
    func log(message: StaticString, currentLevel: LogLevel, args: Array<CVarArg>) {
        if currentLevel.rawValue >= self.level.rawValue {
            switch args.count {
            case 0:
                os_log(message, log: Logger.log, type: self.getLogType(level: currentLevel))
            case 1:
                os_log(message, log: Logger.log, type: self.getLogType(level: currentLevel), args[0])
            case 2:
                os_log(message, log: Logger.log, type: self.getLogType(level: currentLevel), args[0], args[1])
            case 3:
                os_log(message, log: Logger.log, type: self.getLogType(level: currentLevel), args[0], args[1], args[2])
            default:
                os_log(message, log: Logger.log, type: self.getLogType(level: currentLevel))
            }
            
        }
    }
    
    func getLogType(level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return OSLogType.debug
        case .error:
            return OSLogType.error
        case .warning:
            return OSLogType.info
        case .info:
            return OSLogType.info
        default:
            return OSLogType.default
        }
    }
}
