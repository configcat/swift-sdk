import XCTest
@testable import ConfigCat

class CacheTests: XCTestCase {
    func testCacheKeys() {
        XCTAssertEqual("f83ba5d45bceb4bb704410f51b704fb6dfa19942", Utils.generateCacheKey(sdkKey: "configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012"))
        XCTAssertEqual("da7bfd8662209c8ed3f9db96daed4f8d91ba5876", Utils.generateCacheKey(sdkKey: "configcat-sdk-1/TEST_KEY2-123456789012/1234567890123456789012"))
    }
    
    func testPayloads() {
        let testJson = "{\"p\":{\"u\":\"https://cdn-global.configcat.com\",\"r\":0,\"s\":\"FUkC6RADjzF0vXrDSfJn7BcEBag9afw1Y6jkqjMP9BA=\"},\"f\":{\"testKey\":{\"t\":1,\"v\":{\"s\":\"testValue\"}}}}"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let time = formatter.date(from: "2023-06-14T15:27:15.8440000Z")!
        
        let expectedPayload = "1686756435844\ntest-etag\n" + testJson
        
        let entry = try! ConfigEntry.fromConfigJson(json: testJson, eTag: "test-etag", fetchTime: time).get()
        
        XCTAssertEqual(expectedPayload, entry.serialize())
        
        let fromCache = try! ConfigEntry.fromCached(cached: expectedPayload).get()
        
        XCTAssertEqual(time, fromCache.fetchTime)
        XCTAssertEqual(testJson, fromCache.configJson)
        XCTAssertEqual("test-etag", fromCache.eTag)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testCacheTTLRespectsExternalCache() async {
        let testJson = "{\"f\":{\"testKey\":{\"t\":1,\"v\":{\"s\":\"%@\"}}}}"
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJson, "remote"), statusCode: 200))
        
        let entry = try! ConfigEntry.fromConfigJson(json: String(format: testJson, "local"), eTag: "test-etag", fetchTime: Date()).get()
        let cache = SingleValueCache(initValue: entry.serialize())
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 1), logger: NoLogger(), httpEngine: engine, configCache: cache)
        var val = await client.getValue(for: "testKey", defaultValue: "")
        
        XCTAssertEqual("local", val)
        XCTAssertEqual(0, engine.requests.count)
        
        sleep(2)
        
        let entry2 = try! ConfigEntry.fromConfigJson(json: String(format: testJson, "local2"), eTag: "test-etag2", fetchTime: Date()).get()
        try! cache.write(for: "", value: entry2.serialize())
        
        val = await client.getValue(for: "testKey", defaultValue: "")
        
        XCTAssertEqual("local2", val)
        XCTAssertEqual(0, engine.requests.count)
    }
    #endif
}
