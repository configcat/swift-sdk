import Foundation

enum AsyncError: Error {
    case timedOut
    case resultNotPresent
}

enum AsyncState {
    case pending
    case completed
    
    func isCompleted() -> Bool {
        return self == .completed
    }
    
    func isPending() -> Bool {
        return self == .pending
    }
}

class Async {
    fileprivate let queue = DispatchQueue(label: "Async queue")
    fileprivate let semaphore = DispatchSemaphore(value: 0)
    fileprivate var completions = [() -> Void]()
    fileprivate var state = Synced<AsyncState>(initValue: AsyncState.pending)
    
    var completed: Bool {
        return self.state.get().isCompleted()
    }
    
    func complete() {
        self.queue.async {
            if(self.state.get().isPending()) {
                self.state.set(new: .completed)
                for completion in self.completions {
                    completion()
                }
                self.completions.removeAll()
                self.semaphore.signal()
            }
        }
    }
    
    func wait(timeout: Int) throws {
        _ = self.semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(timeout))
        if(self.state.get().isPending()) {
            throw AsyncError.timedOut
        }
    }
    
    func wait() {
        self.semaphore.wait()
    }
    
    @discardableResult
    func accept(completion: @escaping () -> Void) -> Async {
        self.queue.async {
            if self.state.get().isCompleted() {
                completion()
            } else {
                self.completions.append(completion)
            }
        }
        
        return self
    }
    
    @discardableResult
    func apply<NewValue>(completion: @escaping () -> NewValue) -> AsyncResult<NewValue> {
        let result = AsyncResult<NewValue>()
        self.accept {
            let newResult = completion()
            result.complete(result: newResult)
        }
        
        return result
    }
}

final class AsyncResult<Value> : Async {
    fileprivate var result: Value?
    
    override init() {
        super.init()
    }
    
    init(result: Value) {
        super.init()
        self.result = result
        self.state.set(new: .completed)
        self.semaphore.signal()
    }
    
    func complete(result: Value) {
        self.result = result
        super.complete()
    }
    
    func get(timeout: Int) throws -> Value {
        try super.wait(timeout: timeout)
        guard let result = self.result else {
            throw AsyncError.timedOut
        }
        
        return result
    }
    
    func get() throws -> Value {
        super.wait()
        guard let result = self.result else {
            throw AsyncError.resultNotPresent
        }
        
        return result
    }
    
    @discardableResult
    func apply(completion: @escaping (Value) -> Void) -> AsyncResult<Value> {
        self.queue.async {
            if self.state.get().isCompleted() {
                guard let result = self.result else {
                    assert(false, "completion handlers executed on an incomplete AsyncResult")
                    return
                }
                
                completion(result)
            } else {
                self.completions.append({
                    guard let result = self.result else {
                        assert(false, "completion handlers executed on an incomplete AsyncResult")
                        return
                    }
                    
                    completion(result)
                })
            }
        }
        
        return self
    }
    
    @discardableResult
    func apply<NewValue>(completion: @escaping (Value) -> NewValue) -> AsyncResult<NewValue> {
        let result = AsyncResult<NewValue>()
        self.accept { value in
            let newResult = completion(value)
            result.complete(result: newResult)
        }
        
        return result
    }
    
    @discardableResult
    func accept(completion: @escaping (Value) -> Void) -> Async {
        return self.apply(completion: completion)
    }
    
    func compose(completion: @escaping (Value) -> AsyncResult) -> AsyncResult {
        let result = AsyncResult()
        self.accept { value in
            let newResult = completion(value)
            newResult.accept { newVal in
                result.complete(result: newVal)
            }
        }
        
        return result
    }
    
    class func completed(result: Value) -> AsyncResult<Value> {
        return AsyncResult<Value>(result: result)
    }
}
