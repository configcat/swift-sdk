import XCTest
@testable import ConfigCat

class VariationIdTests: XCTestCase {
    let testJson = #"""
                   {"f":{
                       "key1":{
                           "v": {
                              "b": true
                           },
                           "i":"fakeId1",
                           "t": 0,
                           "p":[
                              {
                                 "p":50,
                                 "v":{
                                    "b":true
                                 },
                                 "i":"percentageId1"
                              },
                              {
                                 "p":50,
                                 "v":{
                                    "b":false
                                 },
                                 "i":"percentageId2"
                              }
                           ],
                           "r":[
                              {
                                 "c":[
                                    {
                                       "u":{
                                          "a":"Email",
                                          "c":2,
                                          "l":[
                                             "@configcat.com"
                                          ]
                                       }
                                    }
                                 ],
                                 "s":{
                                    "v":{
                                       "b":true
                                    },
                                    "i":"rolloutId1"
                                 }
                              },
                              {
                                 "c":[
                                    {
                                       "u":{
                                          "a":"Email",
                                          "c":2,
                                          "l":[
                                             "@test.com"
                                          ]
                                       }
                                    }
                                 ],
                                 "s":{
                                    "v":{
                                       "b":false
                                    },
                                    "i":"rolloutId2"
                                 }
                              }
                           ]
                       },
                       "key2":{
                           "v": {
                              "b": false
                           },
                           "i":"fakeId2",
                           "t": 0
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
        ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: httpEngine)
    }
}
