import XCTest
import ConfigCat

class LazyLoadingSyncTests: XCTestCase {

    func testGet() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200, delay: 2))
        
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        //wait for cache invalidation
        sleep(3)
        
        //next call will block until the new value is fetched
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testGetFailedRefresh() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 500))
        
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        //wait for cache invalidation
        sleep(3)
        
        //next call will block until the new value is fetched
        XCTAssertEqual("test", try policy.getConfiguration().get())
    }
    
    func testCacheFails() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let mode = PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, apiKey: "", mode: mode)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache()))
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        //wait for cache invalidation
        sleep(3)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
}
