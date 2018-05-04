import XCTest
import ConfigCat

class ConfigFetcherTests: XCTestCase {

    func testSimpleFetchSuccess() throws {
        let testBody = "test"
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: testBody, statusCode: 200))
        
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "")
        XCTAssertEqual(testBody, try fetcher.getConfigurationJson().get().body)
    }
    
    func testSimpleFetchNotModified() throws {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 304))
        
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "")
        let response = try fetcher.getConfigurationJson().get()
        XCTAssertTrue(response.isNotModified())
        XCTAssertTrue(response.body.isEmpty)
    }
    
    func testSimpleFetchFailed() throws {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 404))
        
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "")
        let response = try fetcher.getConfigurationJson().get()
        XCTAssertTrue(response.isFailed())
        XCTAssertTrue(response.body.isEmpty)
    }
    
    func testFetchNotModifiedEtag() throws {
        let etag = "test"
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 200, headers: ["Etag": etag]))
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 304))
        
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "")
        var response = try fetcher.getConfigurationJson().get()
        XCTAssertTrue(response.isFetched())
        response = try fetcher.getConfigurationJson().get()
        XCTAssertTrue(response.isNotModified())
        
        XCTAssertEqual(etag, mockSession.requests.last?.value(forHTTPHeaderField: "If-None-Match"))
    }
}
