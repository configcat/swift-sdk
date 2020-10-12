import Foundation
import ConfigCat

class MockURLSessionDataTask: URLSessionDataTask {
    private let closure: () -> ()
    init(closure: @escaping () -> ()) {
        self.closure = closure
    }
    
    override func resume() {
        closure()
    }
}

class MockURLSession: URLSession {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    fileprivate var responses = [Response]()
    fileprivate let queue = DispatchQueue(label: "testQueue")
    
    var requests = [URLRequest]()
    
    func enqueueResponse(response: Response) {
        self.responses.append(response)
    }
    
    override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping CompletionHandler
        ) -> URLSessionDataTask {
        self.requests.append(request)
        let response = self.responses.count == 1 ? self.responses[0] : self.responses.removeFirst()
        let semaphore = DispatchSemaphore(value: 0)
        return MockURLSessionDataTask {
            self.queue.async {
                if response.delay > 0 {
                    let _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(response.delay))
                }
                completionHandler(response.data, response.httpResponse, response.error)
            }
        }
    }
}

struct Response {
    let data: Data?
    let httpResponse: HTTPURLResponse
    let error: Error?
    let delay: Int
    
    init(body: String, statusCode: Int, error: Error? = nil, headers: [String: String]? = nil, delay: Int = 0) {
        self.data = body.data(using: .utf8)
        self.httpResponse = HTTPURLResponse(url: URL(string: "url")!, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
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
