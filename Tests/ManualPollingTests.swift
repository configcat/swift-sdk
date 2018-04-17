import XCTest
@testable import ConfigCat

class ManualPollingTests: XCTestCase {
    
    func testGet() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200, delay: 2))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = ManualPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testGetFailedRefresh() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 500))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = ManualPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        XCTAssertEqual("test", try policy.getConfiguration().get())
    }
    
    func testCacheFails() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = ManualPollingPolicy(cache: FailingCache(), fetcher: fetcher)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
}
