import os.log
import os
import Foundation

@objc public enum ConfigCatLogLevel: Int {
    case debug
    case info
    case warning
    case error
    case nolog
}

@objc public protocol ConfigCatLogger {
    func debug(message: String)
    func warning(message: String)
    func info(message: String)
    func error(message: String)
}

class InternalLogger {
    static let noLogger: InternalLogger = InternalLogger(log: NoLogger(), level: .nolog, hooks: Hooks())
    let log: ConfigCatLogger
    let level: ConfigCatLogLevel
    let hooks: Hooks
    
    init(log: ConfigCatLogger, level: ConfigCatLogLevel, hooks: Hooks) {
        self.log = log
        self.level = level
        self.hooks = hooks
    }
    
    func debug(message: String) {
        if ConfigCatLogLevel.debug.rawValue >= level.rawValue {
            log.debug(message: "[0] \(message)")
        }
    }

    func warning(eventId: Int, message: String) {
        if ConfigCatLogLevel.warning.rawValue >= level.rawValue {
            log.warning(message: "[\(eventId)] \(message)")
        }
    }

    func info(eventId: Int, message: String) {
        if ConfigCatLogLevel.info.rawValue >= level.rawValue {
            log.info(message: "[\(eventId)] \(message)")
        }
    }

    func error(eventId: Int, message: String) {
        hooks.invokeOnError(error: message)
        if ConfigCatLogLevel.error.rawValue >= level.rawValue {
            log.error(message: "[\(eventId)] \(message)")
        }
    }
    
    func enabled(level: ConfigCatLogLevel) -> Bool {
        return level.rawValue >= self.level.rawValue
    }
}

class OSLogger: ConfigCatLogger {
    private static let log: OSLog = OSLog(subsystem: "com.configcat", category: "main")
    
    func debug(message: String) {
        os_log("%{public}@", log: OSLogger.log, type: .debug, message)
    }
    
    func warning(message: String) {
        os_log("%{public}@", log: OSLogger.log, type: .info, message)
    }
    
    func info(message: String) {
        os_log("%{public}@", log: OSLogger.log, type: .info, message)
    }
    
    func error(message: String) {
        os_log("%{public}@", log: OSLogger.log, type: .error, message)
    }
}

class NoLogger: ConfigCatLogger {
    func debug(message: String) {
        // do nothing
    }
    
    func warning(message: String) {
        // do nothing
    }
    
    func info(message: String) {
        // do nothing
    }
    
    func error(message: String) {
        // do nothing
    }
}
