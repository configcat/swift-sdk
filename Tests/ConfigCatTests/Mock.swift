import Foundation
@testable import ConfigCat

class MockEngine: HttpEngine {
    private let lock = NSLock()
    private let autoRespond: Bool
    private var responses = [Response]()
    private var capturedRequests = [URLRequest]()
    private var pendingCompletions: [(Data?, URLResponse?, Error?) -> Void] = []

    init(autoRespond: Bool = true) {
        self.autoRespond = autoRespond
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    func get(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        lock.lock()
        capturedRequests.append(request)
        guard autoRespond else {
            pendingCompletions.append(completion)
            lock.unlock()
            return
        }
        let response = next()
        lock.unlock()
        if response.delay <= 0 {
            completion(response.data, response.httpResponse, response.error)
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(response.delay)) {
            completion(response.data, response.httpResponse, response.error)
        }
    }

    func enqueueResponse(response: Response) {
        lock.lock()
        defer { lock.unlock() }
        responses.append(response)
    }

    func respond(_ response: Response) {
        lock.lock()
        let completion = pendingCompletions.isEmpty ? nil : pendingCompletions.removeFirst()
        lock.unlock()
        completion?(response.data, response.httpResponse, response.error)
    }

    private func next() -> Response {
        responses.count == 1 ? responses[0] : responses.removeFirst()
    }
}

struct Response {
    let data: Data?
    let httpResponse: HTTPURLResponse
    let error: Error?
    let delay: Int

    init(body: String, statusCode: Int, error: Error? = nil, headers: [String: String]? = nil, delay: Int = 0) {
        data = body.data(using: .utf8)
        httpResponse = HTTPURLResponse(url: URL(string: "url")!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        self.error = error
        self.delay = delay
    }
}

enum TestError: Error {
    case test
}

class FailingCache: ConfigCache {
    public func read(for key: String) throws -> String {
        throw TestError.test
    }

    public func write(for key: String, value: String) throws {
        throw TestError.test
    }
}

class InMemoryConfigCache: NSObject, ConfigCache {
    public var store = [String: String]()

    public func read(for key: String) throws -> String {
        store[key] ?? ""
    }

    public func write(for key: String, value: String) throws {
        store[key] = value
    }
}

class SingleValueCache: NSObject, ConfigCache {
    var value: String

    init(initValue: String) {
        value = initValue
    }

    public func read(for key: String) throws -> String {
        value
    }

    public func write(for key: String, value: String) throws {
        self.value = value
    }
}

class BlockingCache: ConfigCache {
    private let lock = NSLock()
    private var readCount = 0
    private var storedValue: String
    var staleReadNumber = 2
    var blockStaleRead = true
    var blockWrite = false
    let blockedReadStarted = DispatchSemaphore(value: 0)
    let releaseBlockedRead = DispatchSemaphore(value: 0)
    let blockedWriteStarted = DispatchSemaphore(value: 0)
    let releaseBlockedWrite = DispatchSemaphore(value: 0)
    var staleValue = ""

    init(initialValue: String) {
        storedValue = initialValue
    }

    func read(for key: String) throws -> String {
        lock.lock()
        readCount += 1
        let currentRead = readCount
        let value = storedValue
        lock.unlock()

        if currentRead == staleReadNumber {
            guard blockStaleRead else { return staleValue }
            blockedReadStarted.signal()
            _ = releaseBlockedRead.wait(timeout: .now() + 5)
            return staleValue
        }
        return currentRead == 1 ? value : ""
    }

    func write(for key: String, value: String) throws {
        if blockWrite {
            blockedWriteStarted.signal()
            _ = releaseBlockedWrite.wait(timeout: .now() + 5)
        }
        lock.lock()
        storedValue = value
        lock.unlock()
    }

    var stored: String {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }
}

class EmptySnapshotBuilder: SnapshotBuilderProtocol {
    func buildSnapshot(inMemoryResult: InMemoryResult?) -> ConfigCatClientSnapshot {
        ConfigCatClientSnapshot(flagEvaluator: FlagEvaluator(log: InternalLogger.noLogger, evaluator: RolloutEvaluator(logger: InternalLogger.noLogger), hooks: Hooks()), settingsSnapshot: SettingsResult.empty, cacheState: .noFlagData, defaultUser: nil, log: InternalLogger.noLogger)
    }
    
    var defaultUser: ConfigCatUser?
}
