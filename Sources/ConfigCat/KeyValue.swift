import Foundation

public final class KeyValue: NSObject, Sendable {
    public let key: String?
    private let storedValue: ScalarValue

    public var value: Any? {
        storedValue.anyValue
    }

    init(key: String?, value: ScalarValue) {
        self.key = key
        self.storedValue = value
    }
}
