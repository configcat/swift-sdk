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

    func testGetVariationId() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient(httpEngine: engine)

        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValueDetails(for: "key1", defaultValue: false) { details in
                XCTAssertEqual("fakeId1", details.variationId)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetVariationIdNotFound() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient(httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getValueDetails(for: "nonexisting", defaultValue: false) { details in
                XCTAssertEqual("", details.variationId)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetKeyAndValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJson, statusCode: 200))
        let client = createClient(httpEngine: engine)

        let expectation1 = self.expectation(description: "wait for response")
        let expectation2 = self.expectation(description: "wait for response")
        let expectation3 = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
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
        wait(for: [expectation1, expectation2, expectation3], timeout: 5)
    }

    func testGetKeyAndValueNotFound() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: "{}", statusCode: 200))
        let client = createClient(httpEngine: engine)
        let expectation = self.expectation(description: "wait for response")
        client.forceRefresh { _ in
            client.getKeyAndValue(for: "nonexisting") { result in
                XCTAssertNil(result)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    private func createClient(httpEngine: HttpEngine) -> ConfigCatClient {
        ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), httpEngine: httpEngine)
    }
}
