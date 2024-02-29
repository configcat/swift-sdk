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
}
