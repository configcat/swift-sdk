import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    
    func testGet() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, sdkKey: ""))

        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(3)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testGetFailedRequest() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 500))
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession, logger: Logger.noLogger, sdkKey: "", mode: mode.getPollingIdentifier(),dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, sdkKey: ""))
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(3)
        
        XCTAssertEqual("test", try policy.getConfiguration().get())
    }
    
    func testCacheFails() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, sdkKey: ""))
                
        XCTAssertEqual("test", try policy.getConfiguration().get())
        
        sleep(3)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
    
    func testOnConfigChanged() {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: "test", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "test2", statusCode: 200))
        
        var called = false
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2, onConfigChanged: { () in
            called = true
        })
        let fetcher = ConfigFetcher(session: mockSession,logger: Logger.noLogger, sdkKey: "", mode: mode.getPollingIdentifier(), dataGovernance: DataGovernance.global)
        let policy = mode.accept(visitor: RefreshPolicyFactory(fetcher: fetcher, cache: InMemoryConfigCache(), logger: Logger.noLogger, sdkKey: ""))
        
        sleep(1)
        
        XCTAssertTrue(called)
        
        sleep(3)
        
        XCTAssertEqual("test2", try policy.getConfiguration().get())
    }
}
