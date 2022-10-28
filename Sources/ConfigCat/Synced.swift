import Foundation

@propertyWrapper
struct Synced<Value: Equatable> {
    private let mutex = Mutex()
    private var storedValue: Value

    init(wrappedValue: Value) {
        storedValue = wrappedValue
    }

    var wrappedValue: Value {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return storedValue
        }
        set {
            mutex.lock()
            defer { mutex.unlock() }
            storedValue = newValue
        }
    }

    @discardableResult
    mutating func testAndSet(expect: Value, new: Value) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        let challenge = storedValue == expect
        storedValue = challenge ? new : storedValue
        return challenge
    }

    mutating func getAndSet(new: Value) -> Value {
        mutex.lock()
        defer { mutex.unlock() }
        let old = storedValue
        storedValue = new
        return old
    }
}
