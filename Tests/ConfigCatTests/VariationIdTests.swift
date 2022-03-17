import XCTest
@testable import ConfigCat

class VariationIdTests: XCTestCase {
    var mockSession = MockURLSession()
    let testJson = #"""
                   {"f":{
                       "key1":{
                           "v":true,
                           "i":"fakeId1",
                           "p":[
                               {
                                   "v":true,
                                   "p":50,
                                   "i":"percentageId1"
                               },
                               {
                                   "v":false,
                                   "p":50,
                                   "i":"percentageId2"
                               }
                           ],
                           "r":[
                               {
                                   "a":"Email",
                                   "t":2,
                                   "c":"@configcat.com",
                                   "v":true,
                                   "i":"rolloutId1"
                               },
                               {
                                   "a":"Email",
                                   "t":2,
                                   "c":"@test.com",
                                   "v":false,
                                   "i":"rolloutId2"
                               }
                           ]
                       },
                       "key2":{
                           "v":false,
                           "i":"fakeId2",
                           "p":[],
                           "r":[]
                       }
                   }}
                   """#
    
    override func setUp() {
        super.setUp()
        self.mockSession = MockURLSession()
    }

    func testGetVariationId() {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let variationId = client.getVariationId(for: "key1", defaultVariationId: nil)

        XCTAssertEqual("fakeId1", variationId)
    }

    func testGetVariationIdAsync() {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        let variationId = AsyncResult<String?>()
        client.refresh()
        client.getVariationIdAsync(for: "key2", defaultVariationId: nil) { (result) in
            variationId.complete(result: result)
        }

        XCTAssertEqual("fakeId2", try variationId.get())
    }

    func testGetVariationIdNotFound() {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let variationId = client.getVariationId(for: "nonexisting", defaultVariationId: "defaultId")

        XCTAssertEqual("defaultId", variationId)
    }

    func testGetAllVariationIds() {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let variationIds = client.getAllVariationIds()

        XCTAssertEqual(2, variationIds.count)
        XCTAssertTrue(variationIds.contains("fakeId1"))
        XCTAssertTrue(variationIds.contains("fakeId2"))
    }

    func testGetAllVariationIdsEmpty() {
        mockSession.enqueueResponse(response: Response(body: "{}", statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let variationIds = client.getAllVariationIds()

        XCTAssertEqual(0, variationIds.count)
    }

    func testGetAllVariationIdsAsync() throws {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        let variationIdsResult = AsyncResult<[String]>()
        client.refresh()
        client.getAllVariationIdsAsync() { (result) in
            variationIdsResult.complete(result: result)
        }
        
        let variationIds = try variationIdsResult.get()
        XCTAssertEqual(2, variationIds.count)
        XCTAssertTrue(variationIds.contains("fakeId1"))
        XCTAssertTrue(variationIds.contains("fakeId2"))
    }

    func testGetKeyAndValue() {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        client.refresh()
        if let result = client.getKeyAndValue(for: "fakeId2") {
            XCTAssertEqual("key2", result.key);
            XCTAssertFalse(result.value as! Bool);
        } else {
            XCTFail()
        }

        if let result = client.getKeyAndValue(for: "percentageId2") {
            XCTAssertEqual("key1", result.key);
            XCTAssertFalse(result.value as! Bool);
        } else {
            XCTFail()
        }

        if let result = client.getKeyAndValue(for: "rolloutId2") {
            XCTAssertEqual("key1", result.key);
            XCTAssertFalse(result.value as! Bool);
        } else {
            XCTFail()
        }
    }

    func testGetKeyAndValueAsync() throws {
        mockSession.enqueueResponse(response: Response(body: self.testJson, statusCode: 200))
        let client = self.createClient()
        let keyValueResult = AsyncResult<KeyValue>()
        client.refresh()
        client.getKeyAndValueAsync(for: "fakeId1") { (result) in
            if let result = result {
                keyValueResult.complete(result: result)
            } else {
                XCTFail()
            }
        }

        let keyValue = try keyValueResult.get()
        XCTAssertEqual("key1", keyValue.key);
        XCTAssertTrue(keyValue.value as! Bool);
    }

    func testGetKeyAndValueNotFound() {
        mockSession.enqueueResponse(response: Response(body: "{}", statusCode: 200))
        let client = self.createClient()
        client.refresh()
        let result = client.getKeyAndValue(for: "nonexisting")
        XCTAssertNil(result)
    }

    private func createClient() -> ConfigCatClient {
        return ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: self.mockSession)
    }
}
