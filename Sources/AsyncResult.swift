import Foundation
import Dispatch

enum AsyncError: Error {
    case timedOut
    case resultNotPresent
}

enum AsyncState {
    case pending
    case completed
    
    public func isCompleted() -> Bool {
        return self == .completed
    }
    
    public func isPending() -> Bool {
        return self == .pending
    }
}

public class Async {
    fileprivate let queue = DispatchQueue(label: "Async queue")
    fileprivate let semaphore = DispatchSemaphore(value: 0)
    fileprivate var completions = [() -> Void]()
    fileprivate var state = AsyncState.pending
    
    var completed: Bool {
        return self.state.isCompleted()
    }
    
    public func complete() {
        self.queue.async {
            if(self.state.isPending()) {
                self.state = .completed
                self.semaphore.signal()
                for completion in self.completions {
                    completion()
                }
                self.completions.removeAll()
            }
        }
    }
    
    public func wait(timeout: Int) throws {
        _ = self.semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(timeout))
        if(self.state.isPending()) {
            throw AsyncError.timedOut
        }
    }
    
    public func wait() {
        self.semaphore.wait()
    }
    
    @discardableResult
    public func accept(completion: @escaping () -> Void) -> Async {
        self.queue.async {
            if self.state.isCompleted() {
                completion()
            } else {
                self.completions.append(completion)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func apply<NewValue>(completion: @escaping () -> NewValue) -> AsyncResult<NewValue> {
        let result = AsyncResult<NewValue>()
        self.accept {
            let newResult = completion()
            result.complete(result: newResult)
        }
        
        return result
    }
}

public final class AsyncResult<Value> : Async {
    fileprivate var result: Value?
    
    override init() {
        super.init()
    }
    
    init(result: Value) {
        super.init()
        self.result = result
        self.state = .completed
        self.semaphore.signal()
    }
    
    public func complete(result: Value) {
        self.result = result
        super.complete()
    }
    
    public func get(timeout: Int) throws -> Value {
        try super.wait(timeout: timeout)
        guard let result = self.result else {
            throw AsyncError.timedOut
        }
        
        return result
    }
    
    public func get() throws -> Value {
        super.wait()
        guard let result = self.result else {
            throw AsyncError.resultNotPresent
        }
        
        return result
    }
    
    @discardableResult
    public func apply(completion: @escaping (Value) -> Void) -> AsyncResult<Value> {
        self.queue.async {
            if self.state.isCompleted() {
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
    public func apply<NewValue>(completion: @escaping (Value) -> NewValue) -> AsyncResult<NewValue> {
        let result = AsyncResult<NewValue>()
        self.accept { value in
            let newResult = completion(value)
            result.complete(result: newResult)
        }
        
        return result
    }
    
    @discardableResult
    public func accept(completion: @escaping (Value) -> Void) -> Async {
        return self.apply(completion: completion)
    }
    
    public class func completed(result: Value) -> AsyncResult<Value> {
        return AsyncResult<Value>(result: result)
    }
}
