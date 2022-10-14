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
    static let noLogger: Logger = Logger(level: .nolog, hooks: Hooks())
    private static let log: OSLog = OSLog(subsystem: "com.configcat", category: "main")
    private let level: LogLevel
    private let hooks: Hooks

    init(level: LogLevel, hooks: Hooks) {
        self.level = level
        self.hooks = hooks
    }

    func debug(message: StaticString, _ args: CVarArg...) {
        log(message: message, currentLevel: .debug, args: args)
    }

    func warning(message: StaticString, _ args: CVarArg...) {
        log(message: message, currentLevel: .warning, args: args)
    }

    func info(message: StaticString, _ args: CVarArg...) {
        log(message: message, currentLevel: .info, args: args)
    }

    func error(message: StaticString, _ args: CVarArg...) {
        let msg = message.stringValue.replacingOccurrences(of: "{public}", with: "")
        hooks.invokeOnError(error: String(format: msg, args))
        log(message: message, currentLevel: .error, args: args)
    }

    func log(message: StaticString, currentLevel: LogLevel, args: Array<CVarArg>) {
        if currentLevel.rawValue >= level.rawValue {
            switch args.count {
            case 0:
                os_log(message, log: Logger.log, type: getLogType(level: currentLevel))
            case 1:
                os_log(message, log: Logger.log, type: getLogType(level: currentLevel), args[0])
            case 2:
                os_log(message, log: Logger.log, type: getLogType(level: currentLevel), args[0], args[1])
            case 3:
                os_log(message, log: Logger.log, type: getLogType(level: currentLevel), args[0], args[1], args[2])
            default:
                os_log(message, log: Logger.log, type: getLogType(level: currentLevel))
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
