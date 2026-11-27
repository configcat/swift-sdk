import Foundation
@testable import ConfigCat

extension ConfigCatClient {
    func ensureStarted() -> ConfigCatClient {
        start()
        return self
    }
}

extension ConfigService {
    func ensureStarted() -> ConfigService {
        start()
        return self
    }
}

final class MockEngine: HttpEngine, @unchecked Sendable {
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

    func get(request: URLRequest, completion: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
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
    let httpResponse: URLResponse?
    let error: Error?
    let delay: Int

    init(body: String, statusCode: Int, error: Error? = nil, headers: [String: String]? = nil, delay: Int = 0) {
        data = body.data(using: .utf8)
        httpResponse = HTTPURLResponse(url: URL(string: "url")!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        self.error = error
        self.delay = delay
    }

    init(response: URLResponse?) {
        data = nil
        httpResponse = response
        error = nil
        delay = 0
    }
}

enum TestError: Error {
    case test
}

final class FailingCache: ConfigCache {
    public func read(for key: String) throws -> String {
        throw TestError.test
    }

    public func write(for key: String, value: String) throws {
        throw TestError.test
    }
}

final class InMemoryConfigCache: NSObject, ConfigCache, @unchecked Sendable {
    private let lock = NSLock()
    private var values = [String: String]()

    var store: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    public func read(for key: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        return values[key] ?? ""
    }

    public func write(for key: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
}

final class SingleValueCache: NSObject, ConfigCache, Sendable {
    private let value: Locked<String>

    init(initValue: String) {
        value = Locked(initValue)
    }

    public func read(for key: String) throws -> String {
        return value.withLock { $0 }
    }

    public func write(for key: String, value: String) throws {
        self.value.withLock { $0 = value }
    }
}

final class ObservingCache: ConfigCache {
    let readStarted = DispatchSemaphore(value: 0)

    func read(for key: String) throws -> String {
        readStarted.signal()
        return ""
    }

    func write(for key: String, value: String) throws {}
}

final class BlockingCache: ConfigCache, @unchecked Sendable {
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

final class EmptySnapshotBuilder: SnapshotBuilderProtocol {
    private let storedDefaultUser: Locked<ConfigCatUser?> = Locked(nil)

    func buildSnapshot(inMemoryResult: InMemoryResult?) -> ConfigCatClientSnapshot {
        ConfigCatClientSnapshot(flagEvaluator: FlagEvaluator(log: InternalLogger.noLogger, evaluator: RolloutEvaluator(logger: InternalLogger.noLogger), hooks: Hooks()), settingsSnapshot: SettingsResult.empty, cacheState: inMemoryResult?.cacheState ?? .noFlagData, defaultUser: nil, log: InternalLogger.noLogger)
    }
    
    var defaultUser: ConfigCatUser? {
        return storedDefaultUser.withLock { $0 }
    }

    func setDefaultUser(user: ConfigCatUser?) {
        storedDefaultUser.withLock { $0 = user }
    }
}
