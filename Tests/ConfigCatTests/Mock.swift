import Foundation
@testable import ConfigCat

class MockHTTP {
    private static var responses = [Response]()
    static var requests = [URLRequest]()

    static func enqueueResponse(response: Response) {
        responses.append(response)
    }

    static func next() -> Response {
        responses.count == 1 ? responses[0] : responses.removeFirst()
    }

    static func reset() {
        responses.removeAll()
        requests.removeAll()
    }

    static func session(config: URLSessionConfiguration = URLSessionConfiguration.default) -> URLSession {
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession.init(configuration: config)
    }
}

class MockURLProtocol: URLProtocol {
    private var requestJob: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockHTTP.requests.append(request)
        let response = MockHTTP.next()
        if response.delay <= 0 {
            finish(response: response)
            return
        }

        requestJob = DispatchWorkItem(block: { [weak self] in
            guard let self = self else { return }
            self.finish(response: response)
        })

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
                .asyncAfter(deadline: .now() + .seconds(response.delay), execute: requestJob!)
    }

    override func stopLoading() {
        requestJob?.cancel()
    }

    private func finish(response: Response) {
        if let error = response.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocol(self, didReceive: response.httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data ?? Data())
            client?.urlProtocolDidFinishLoading(self)
        }
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

enum TestError : Error {
    case test
}

public class FailingCache : ConfigCache {
    public func read(for key: String) throws -> String {
        throw TestError.test
    }
    
    public func write(for key: String, value: String) throws {
        throw TestError.test
    }
}

public class InMemoryConfigCache : NSObject, ConfigCache {
    public var store = [String: String]()

    public func read(for key: String) throws -> String {
        store[key] ?? ""
    }

    public func write(for key: String, value: String) throws {
        store[key] = value
    }
}
