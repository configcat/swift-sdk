import Foundation

public final class KeyValue: NSObject, Sendable {
    public let key: String?
    private let storedValue: FlagValue

    public var value: Any? {
        storedValue.rawValue
    }

    init(key: String?, value: FlagValue) {
        self.key = key
        self.storedValue = value
    }
}
