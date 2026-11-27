#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Foundation

final class Mutex: @unchecked Sendable {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

    init(recursive: Bool = false) {
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        if recursive {
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        } else {
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
        }
        let result = pthread_mutex_init(mutex, &attr)
        assert(result == 0, "Failed to init mutex.")
    }

    deinit {
        let result = pthread_mutex_destroy(mutex)
        assert(result == 0, "Failed to destroy mutex.")
        mutex.deallocate()
    }

    private func lock() {
        let result = pthread_mutex_lock(mutex)
        assert(result == 0, "Failed to lock mutex.")
    }

    private func unlock() {
        let result = pthread_mutex_unlock(mutex)
        assert(result == 0, "Failed to unlock mutex.")
    }

    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}

/// Protects access to a value. Mutable references obtained from the value must
/// not be used outside the lock unless they are independently synchronized.
/// The lock is non-recursive; its closures must not re-enter the same instance.
final class Locked<Value> {
    private let mutex = Mutex()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try mutex.withLock { try body(&storedValue) }
    }
}

extension Locked: @unchecked Sendable where Value: Sendable {}
