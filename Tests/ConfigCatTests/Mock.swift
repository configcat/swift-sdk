import Foundation
@testable import ConfigCat

class MockEngine: HttpEngine {
    private var responses = [Response]()
    private var capturedRequests = [URLRequest]()

    var requests: [URLRequest] { get { capturedRequests } }

    func get(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        capturedRequests.append(request)
        let response = next()
        if response.delay <= 0 {
            completion(response.data, response.httpResponse, response.error)
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(response.delay)) {
            completion(response.data, response.httpResponse, response.error)
        }
    }

    func enqueueResponse(response: Response) {
        responses.append(response)
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
