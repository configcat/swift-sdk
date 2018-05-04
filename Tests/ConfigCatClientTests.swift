import XCTest
import ConfigCat

class ConfigCatClientTests: XCTestCase {
    var mockSession = MockURLSession()
    
    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }
    
    func testGetConfigurationJson() {
        let body = "{ \"fakeKey\":\"fakeValue\" }"
        mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let client = self.createClient()
        let json = client.getConfigurationJsonString()
        XCTAssertEqual(body, json)
    }
    
    func testGetConfiguration() throws {
        let encoder = JSONEncoder()
        let sample = Sample()
        let body = String(describing: try encoder.encode(sample))
        mockSession.enqueueResponse(response: Response(body: body, statusCode: 200))
        let client = self.createClient()
        let config = client.getConfiguration(defaultValue: Sample.Empty)
        
        XCTAssertEqual(sample.BoolProp, config.BoolProp)
        XCTAssertEqual(sample.StringProp, config.StringProp)
        XCTAssertEqual(sample.DoubleProp, config.DoubleProp)
        XCTAssertEqual(sample.IntProp, config.IntProp)
    }
    
    func testGetConfigurationReturnsDefaultOnFail() throws {
        let encoder = JSONEncoder()
        let sample = Sample()
        let body = String(describing: try encoder.encode(sample))
        mockSession.enqueueResponse(response: Response(body: body, statusCode: 500))
        let client = self.createClient()
        let config = client.getConfiguration(defaultValue: Sample.Empty)
        
        XCTAssertEqual(Sample.Empty, config)
    }
    
    func testGetConfigurationReturnsDefaultOnError() {
        mockSession.enqueueResponse(response: Response(body: "{ test: test] }", statusCode: 200))
        let client = self.createClient()
        let config = client.getConfiguration(defaultValue: Sample.Empty)
        
        XCTAssertEqual(Sample.Empty, config)
    }
    
    func testGetIntValue() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":43 }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 10)
        
        XCTAssertEqual(43, config)
    }
    
    func testGetIntValueFailed() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"fake\" }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 10)
        
        XCTAssertEqual(10, config)
    }
    
    func testGetStringValue() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"fake\" }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: "def")
        
        XCTAssertEqual("fake", config)
    }
    
    func testGetStringValueFailed() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":33 }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: "def")
        
        XCTAssertEqual("def", config)
    }
    
    func testGetDoubleValue() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":43.56 }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 34.23)
        
        XCTAssertEqual(43.56, config)
    }
    
    func testGetDoubleValueFailed() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"fake\" }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: 23.54)
        
        XCTAssertEqual(23.54, config)
    }
    
    func testGetBoolValue() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":true }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: false)
        
        XCTAssertTrue(config)
    }
    
    func testGetBoolValueFailed() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"fake\" }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: true)
        
        XCTAssertTrue(config)
    }
    
    func testGetValueWithInvalidTypeFailed() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"fake\" }", statusCode: 200))
        let client = self.createClient()
        let config = client.getValue(for: "fakeKey", defaultValue: Float(55))
        
        XCTAssertEqual(Float(55), config)
    }
    
    func testForceRefresh() {
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"test\" }", statusCode: 200))
        mockSession.enqueueResponse(response: Response(body: "{ \"fakeKey\":\"test2\" }", statusCode: 200))
        let fetcher = ConfigFetcher(session: self.mockSession, apiKey: "")
        let policy = ExpiringCachePolicy(cache: InMemoryConfigCache(), fetcher: fetcher, cacheRefreshIntervalInSeconds: 120, useAsyncRefresh: false)
        let client = ConfigCatClient(apiKey: "test", policyFactory: { (cache, fetcher) -> RefreshPolicy in
            policy
        })
        
        XCTAssertEqual("test", client.getValue(for: "fakeKey", defaultValue: "def"))
        
        client.refresh()
        
        XCTAssertEqual("test2", client.getValue(for: "fakeKey", defaultValue: "def"))
    }
    
    private func createClient() -> ConfigCatClient {
        let fetcher = ConfigFetcher(session: self.mockSession, apiKey: "")
        let policy = ManualPollingPolicy(cache: InMemoryConfigCache(), fetcher: fetcher)
        return ConfigCatClient(apiKey: "test", policyFactory: { (cache, fetcher) -> RefreshPolicy in
            policy
        })
    }
}

class Sample : Encodable, Decodable, Equatable {
    static let Empty = Sample()
    let StringProp = "test"
    let DoubleProp = 2.4
    let IntProp = 3
    let BoolProp = true
    
    static func ==(lhs: Sample, rhs: Sample) -> Bool {
        return lhs === rhs
    }
}
