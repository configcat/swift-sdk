import XCTest
@testable import ConfigCat

class SyncedTests: XCTestCase {
    private final class State {
        @Synced var value = String(repeating: "0", count: 100)
    }

    func testReadAndWrite() {
        let value = Synced(wrappedValue: 1)

        XCTAssertEqual(1, value.wrappedValue)
        value.wrappedValue = 2
        XCTAssertEqual(2, value.wrappedValue)
    }

    func testTestAndSet() {
        let value = Synced(wrappedValue: 1)

        XCTAssertFalse(value.testAndSet(expect: 0, new: 2))
        XCTAssertEqual(1, value.wrappedValue)
        XCTAssertTrue(value.testAndSet(expect: 1, new: 2))
        XCTAssertEqual(2, value.wrappedValue)
    }

    func testGetAndSet() {
        let value = Synced(wrappedValue: 1)

        XCTAssertEqual(1, value.getAndSet(new: 2))
        XCTAssertEqual(2, value.wrappedValue)
    }

    func testConcurrentWrappedReadsAndWrites() {
        let state = State()
        let values = (0..<10).map { String(repeating: String($0), count: 100) }

        DispatchQueue.concurrentPerform(iterations: 1_000) { iteration in
            state.value = values[iteration % values.count]
            XCTAssertTrue(values.contains(state.value))
        }
    }

    func testConcurrentTestAndSet() {
        let value = Synced(wrappedValue: 0)
        let iterations = 1_000

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            while true {
                let current = value.wrappedValue
                if value.testAndSet(expect: current, new: current + 1) {
                    break
                }
            }
        }

        XCTAssertEqual(iterations, value.wrappedValue)
    }

    func testConcurrentGetAndSet() {
        let value = Synced(wrappedValue: -1)
        let iterations = 1_000
        let resultsLock = NSLock()
        var previousValues: [Int] = []

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            let previous = value.getAndSet(new: iteration)
            resultsLock.lock()
            previousValues.append(previous)
            resultsLock.unlock()
        }

        previousValues.append(value.wrappedValue)
        XCTAssertEqual(Array(-1..<iterations), previousValues.sorted())
    }
}