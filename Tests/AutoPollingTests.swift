import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    
    func testGet() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = AutoPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher, autoPollIntervalInSeconds: 2)
        
        sleep(1)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(2)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testGetFailedRequest() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 500))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = AutoPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher, autoPollIntervalInSeconds: 2)
        
        sleep(1)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(2)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
    }
    
    func testCacheFails() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = AutoPollingPolicy(cache: FailingCache(), fetcher: fetcher, autoPollIntervalInSeconds: 2)
        
        sleep(1)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(2)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testOnConfigChanged() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        var newConfig = ""
        let fetcher = ConfigFetcher(session: mockSession, projectSecret: "")
        let policy = AutoPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher, autoPollIntervalInSeconds: 2,
        onConfigChanged: { (config, parser) in
            newConfig = config
        })
        
        sleep(1)
        
        XCTAssertEqual("test", newConfig)
        
        sleep(2)
        
        XCTAssertEqual("test2", newConfig)
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
}
