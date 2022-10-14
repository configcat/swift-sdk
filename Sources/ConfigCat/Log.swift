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

    func debug(message: String) {
        log(message: message, currentLevel: .debug)
    }

    func warning(message: String) {
        log(message: message, currentLevel: .warning)
    }

    func info(message: String) {
        log(message: message, currentLevel: .info)
    }

    func error(message: String) {
        hooks.invokeOnError(error: message)
        log(message: message, currentLevel: .error)
    }

    func log(message: String, currentLevel: LogLevel) {
        if currentLevel.rawValue >= level.rawValue {
            os_log("%{public}@", log: Logger.log, type: getLogType(level: currentLevel), message)
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
