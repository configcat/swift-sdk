import Foundation

@propertyWrapper
struct Synced<Value: Equatable> {
    private let mutex = Mutex()
    private var storedValue: Value

    init(wrappedValue: Value) {
        storedValue = wrappedValue
    }

    var wrappedValue: Value {
        get { mutex.withLock { storedValue } }
        set { mutex.withLock { storedValue = newValue } }
    }

    @discardableResult
    mutating func testAndSet(expect: Value, new: Value) -> Bool {
        mutex.withLock {
            let challenge = storedValue == expect
            storedValue = challenge ? new : storedValue
            return challenge
        }
    }

    mutating func getAndSet(new: Value) -> Value {
        mutex.withLock {
            let old = storedValue
            storedValue = new
            return old
        }
    }
}
