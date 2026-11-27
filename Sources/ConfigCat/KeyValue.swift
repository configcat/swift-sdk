import Foundation

public final class KeyValue: NSObject, Sendable {
    @objc public let key: String?
    private let storedValue: FlagValue

    @objc public var value: Any? {
        storedValue.rawValue
    }

    init(key: String?, value: FlagValue) {
        self.key = key
        self.storedValue = value
    }
}
