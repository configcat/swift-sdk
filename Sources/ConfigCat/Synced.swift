import Foundation

class Synced<Value: Equatable> {    
    fileprivate let lock = DispatchSemaphore(value: 1)
    fileprivate var value: Value
    
    init(initValue: Value) {
        self.value = initValue
    }
    
    func get() -> Value {
        lock.wait()
        defer { lock.signal() }
        return value
    }
    
    func set(new: Value) {
        lock.wait()
        defer { lock.signal() }
        self.value = new
    }
    
    func testAndSet(expect: Value, new: Value) -> Bool {
        lock.wait()
        defer { lock.signal() }
        let challange = self.value == expect
        self.value = challange ? new : self.value
        return challange
    }
    
    func getAndSet(new: Value) -> Value {
        lock.wait()
        defer { lock.signal() }
        let old = self.value
        self.value = new
        return old
    }
}
