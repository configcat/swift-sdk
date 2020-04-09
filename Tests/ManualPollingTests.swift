import XCTest
import ConfigCat

class ManualPollingTests: XCTestCase {
    
    func testGet() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200, delay: 2))
        
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession, sdkkey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        
        policy.refresh().wait()
        XCTAssertEqual("test", try policy.getConfiguration().get())
        policy.refresh().wait()
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testGetFailedRefresh() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 500))
        
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession, sdkkey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        policy.refresh().wait()
        XCTAssertEqual("test", try policy.getConfiguration().get())
        policy.refresh().wait()
        XCTAssertEqual("test", try policy.getConfiguration().get())
    }
    
    func testCacheFails() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let mode = PollingModes.manualPoll()
        let fetcher = ConfigFetcher(session: mockSession, sdkkey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        policy.refresh().wait()
        XCTAssertEqual("test", try policy.getConfiguration().get())
        policy.refresh().wait()
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
}
