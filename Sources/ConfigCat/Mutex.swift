#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Foundation

class Mutex {
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

    init(recursive: Bool = false) {
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        if recursive {
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        } else {
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
        }
        pthread_mutex_init(mutex, &attr)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
    }

    func lock() {
        pthread_mutex_lock(mutex)
    }

    func tryLock() -> Bool {
        pthread_mutex_trylock(mutex) == 0
    }

    func unlock() {
        pthread_mutex_unlock(mutex)
    }
}
