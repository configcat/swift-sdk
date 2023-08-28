import XCTest
@testable import ConfigCat

class CacheTests: XCTestCase {
    func testCacheKeys() {
        XCTAssertEqual("147c5b4c2b2d7c77e1605b1a4309f0ea6684a0c6", Utils.generateCacheKey(sdkKey: "test1"))
        XCTAssertEqual("c09513b1756de9e4bc48815ec7a142b2441ed4d5", Utils.generateCacheKey(sdkKey: "test2"))
    }
    
    func testPayloads() {
        let testJson = "{\"p\":{\"u\":\"https://cdn-global.configcat.com\",\"r\":0},\"f\":{\"testKey\":{\"v\":\"testValue\",\"t\":1,\"p\":[],\"r\":[]}}}"
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
