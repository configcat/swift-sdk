import XCTest
import ConfigCat

class ConfigCatClientTests: XCTestCase {
    var mockSession = MockURLSession()
    let testJsonFormat = "{ \"fakeKey\": { \"v\": %@, \"p\": [] ,\"r\": [] } }"
    
    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testGetIntValue() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "43"), statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let config = client.getValue(for: "fakeKey", defaultValue: 10)
        
        XCTAssertEqual(43, config)
    }
    
    func testGetIntValueFailed() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "fake"), statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 10)
        
        XCTAssertEqual(10, config)
    }
    
    func testGetIntValueFailedInvalidJson() {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 10)
        
        XCTAssertEqual(10, config)
    }
    
    func testGetStringValue() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "\"fake\""), statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let config = client.getValue(for: "fakeKey", defaultValue: "def")
        
        XCTAssertEqual("fake", config)
    }
    
    func testGetStringValueFailed() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "33"), statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: "def")
        
        XCTAssertEqual("def", config)
    }
    
    func testGetDoubleValue() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "43.56"), statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let config = client.getValue(for: "fakeKey", defaultValue: 34.23)
        
        XCTAssertEqual(43.56, config)
    }
    
    func testGetDoubleValueFailed() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "fake"), statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 23.54)
        
        XCTAssertEqual(23.54, config)
    }
    
    func testGetBoolValue() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "true"), statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let config = client.getValue(for: "fakeKey", defaultValue: false)
        
        XCTAssertTrue(config)
    }
    
    func testGetBoolValueFailed() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "fake"), statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: true)
        
        XCTAssertTrue(config)
    }
    
    func testGetValueWithInvalidTypeFailed() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "fake"), statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: Float(55))
        
        XCTAssertEqual(Float(55), config)
    }
    
    func testGetLatestOnFail() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "55"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = self.createClient()
        client.refresh()
        var config = client.getValue(for: "fakeKey", defaultValue: 0)
        XCTAssertEqual(55, config)
        client.refresh()
        config = client.getValue(for: "fakeKey", defaultValue: 0)
        XCTAssertEqual(55, config)
    }
    
    func testGetLatestOnFailAsync() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "55"), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = self.createClient()
        let config = AsyncResult<Int>()
        client.refresh()
        client.getValueAsync(for: "fakeKey", defaultValue: 0) { (result) in
            config.complete(result: result)
        }
        
        XCTAssertEqual(55, try config.get())
        
        client.refresh()
        let config2 = AsyncResult<Int>()
        client.getValueAsync(for: "fakeKey", defaultValue: 0) { (result) in
            config2.complete(result: result)
        }
        
        XCTAssertEqual(55, try config2.get())
    }
    
    func testForceRefresh() {
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "\"test\""), statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "\"test2\""), statusCode: 200))
        
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: self.mockSession)
        
        XCTAssertEqual("test", client.getValue(for: "fakeKey", defaultValue: "def"))
        
        client.refresh()
        
        XCTAssertEqual("test2", client.getValue(for: "fakeKey", defaultValue: "def"))
    }
    
    func testFailingAutoPoll() {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 500))
        
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: self.mockSession)
        
        XCTAssertEqual("def", client.getValue(for: "fakeKey", defaultValue: "def"))
    }
    
    func testFailingExpiringCache() {
        mockSession.enqueueResponse(response: Response(body: "", statusCode: 500))
        
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: self.mockSession)
        
        XCTAssertEqual("def", client.getValue(for: "fakeKey", defaultValue: "def"))
    }
    
    func testGetAllKeys() {
        let client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A")
        let keys = client.getAllKeys()
        XCTAssertEqual(16, keys.count)
        XCTAssertTrue(keys.contains("stringDefaultCat"))
    }
    
    private func createClient() -> ConfigCatClient {
        return ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: self.mockSession)
    }
}
