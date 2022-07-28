import XCTest
@testable import ConfigCat

class VariationIdTests: XCTestCase {
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
        MockHTTP.reset()
    }

    func testGetVariationId() {
        MockHTTP.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient()

        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getVariationId(for: "key1", defaultVariationId: nil) { variationId in
                XCTAssertEqual("fakeId1", variationId)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetVariationIdNotFound() {
        MockHTTP.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getVariationId(for: "nonexisting", defaultVariationId: "def") { variationId in
                XCTAssertEqual("def", variationId)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetAllVariationIds() {
        MockHTTP.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient()

        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getAllVariationIds { variationIds in
                XCTAssertEqual(2, variationIds.count)
                XCTAssertTrue(variationIds.contains("fakeId1"))
                XCTAssertTrue(variationIds.contains("fakeId2"))
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetAllVariationIdsEmpty() {
        MockHTTP.enqueueResponse(response: Response(body: "{}", statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getAllVariationIds { variationIds in
                XCTAssertEqual(0, variationIds.count)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetKeyAndValue() {
        MockHTTP.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient()

        let expectation1 = self.expectation(description: "wait for response")
        let expectation2 = self.expectation(description: "wait for response")
        let expectation3 = self.expectation(description: "wait for response")
        client.refresh {
            client.getKeyAndValue(for: "fakeId2") { kv in
                if let result = kv {
                    XCTAssertEqual("key2", result.key)
                    XCTAssertFalse(result.value as! Bool)
                } else {
                    XCTFail()
                }
                expectation1.fulfill()
            }
            client.getKeyAndValue(for: "percentageId2") { kv in
                if let result = kv {
                    XCTAssertEqual("key1", result.key)
                    XCTAssertFalse(result.value as! Bool)
                } else {
                    XCTFail()
                }
                expectation2.fulfill()
            }
            client.getKeyAndValue(for: "rolloutId2") { kv in
                if let result = kv {
                    XCTAssertEqual("key1", result.key)
                    XCTAssertFalse(result.value as! Bool)
                } else {
                    XCTFail()
                }
                expectation3.fulfill()
            }
        }
        wait(for: [expectation1, expectation2, expectation3], timeout: 2)
    }

    func testGetKeyAndValueNotFound() {
        MockHTTP.enqueueResponse(response: Response(body: "{}", statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getKeyAndValue(for: "nonexisting") { result in
                XCTAssertNil(result)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    private func createClient() -> ConfigCatClient {
        ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
    }
}
