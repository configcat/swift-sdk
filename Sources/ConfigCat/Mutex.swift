#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Foundation

class Mutex {
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

    func lock() {
        let result = pthread_mutex_lock(mutex)
        assert(result == 0, "Failed to lock mutex.")
    }

    func tryLock() -> Bool {
        pthread_mutex_trylock(mutex) == 0
    }

    func unlock() {
        let result = pthread_mutex_unlock(mutex)
        assert(result == 0, "Failed to unlock mutex.")
    }
}

extension Mutex {
    func withLock<Result>(block: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try block()
    }
}
