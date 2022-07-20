import Foundation

class Synced<Value: Equatable> {    
    fileprivate let mutex = Mutex()
    fileprivate var value: Value
    
    init(initValue: Value) {
        value = initValue
    }
    
    func get() -> Value {
        mutex.lock()
        defer { mutex.unlock() }
        return value
    }
    
    func set(new: Value) {
        mutex.lock()
        defer { mutex.unlock() }
        value = new
    }

    @discardableResult
    func testAndSet(expect: Value, new: Value) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        let challenge = value == expect
        value = challenge ? new : value
        return challenge
    }
    
    func getAndSet(new: Value) -> Value {
        mutex.lock()
        defer { mutex.unlock() }
        let old = value
        value = new
        return old
    }
}
