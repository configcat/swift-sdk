import Foundation

class MutableQueue<T> {
    private var store = [T]()

    func enqueue(item: T) {
        store.append(item)
    }

    func dequeue() -> T? {
        store.isEmpty ? nil : store.removeFirst()
    }

    var isEmpty: Bool {
        get {
            store.isEmpty
        }
    }
}
