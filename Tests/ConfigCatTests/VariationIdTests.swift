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

    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetKeyAndValueAcrossTasks() async throws {
        let json = #"""
        {"f":{
            "boolKey":{"t":0,"v":{"b":true},"i":"boolId"},
            "stringKey":{"t":1,"v":{"s":"text"},"i":"stringId"},
            "intKey":{"t":2,"v":{"i":42},"i":"intId"},
            "doubleKey":{"t":3,"v":{"d":1.5},"i":"doubleId"}
        }}
        """#
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: json, statusCode: 200))
        let client = createClient(httpEngine: engine)
        defer { client.close() }
        let refresh = await client.forceRefresh()
        XCTAssertTrue(refresh.success)

        var results = [String: KeyValue]()
        for id in ["boolId", "stringId", "intId", "doubleId"] {
            let result = await client.getKeyAndValue(for: id)
            let transferred = await Task.detached { result }.value
            results[id] = try XCTUnwrap(transferred)
        }

        XCTAssertEqual("boolKey", results["boolId"]?.key)
        XCTAssertEqual(true, results["boolId"]?.value as? Bool)
        XCTAssertEqual("stringKey", results["stringId"]?.key)
        XCTAssertEqual("text", results["stringId"]?.value as? String)
        XCTAssertEqual("intKey", results["intId"]?.key)
        XCTAssertEqual(42, results["intId"]?.value as? Int)
        XCTAssertEqual("doubleKey", results["doubleId"]?.key)
        XCTAssertEqual(1.5, results["doubleId"]?.value as? Double)
    }
    #endif

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
        ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: NoLogger(), httpEngine: httpEngine).ensureStarted()
    }
}
