import XCTest
@testable import ConfigCat

class ConfigCatClientTests: XCTestCase {
    let testJsonFormat = #"{ "f": { "fakeKey": { "v": %@, "p": [], "r": [] } } }"#
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testGetIntValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(43, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetIntValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetIntValueFailedInvalidJson() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 10) { value in
                XCTAssertEqual(10, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetStringValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"fake\""), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("fake", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetStringValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "33"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: "def") { value in
                XCTAssertEqual("def", value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetDoubleValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "43.56"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(43.56, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetDoubleValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 3.14) { value in
                XCTAssertEqual(3.14, value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetBoolValue() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "true"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertTrue(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetBoolValueFailed() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 404, error: TestError.test))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: false) { value in
                XCTAssertFalse(value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetValueWithInvalidTypeFailed() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "fake"), statusCode: 200))
        let client = createClient()
        let expectation = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: Float(55)) { value in
                XCTAssertEqual(Float(55), value)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func testGetLatestOnFail() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "55"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = createClient()
        let expectation1 = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: 0) { value in
                XCTAssertEqual(55, value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testForceRefreshLazy() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: MockHTTP.session())

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testForceRefreshAuto() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test\""), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "\"test2\""), statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())

        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("test", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)

        let expectation2 = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("test2", value)
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2)
    }

    func testFailingAutoPoll() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testFailingAutoPollRefresh() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.autoPoll(autoPollIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.refresh {
            client.getValue(for: "fakeKey", defaultValue: "") { value in
                XCTAssertEqual("", value)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testFailingExpiringCache() {
        MockHTTP.enqueueResponse(response: Response(body: "", statusCode: 500))
        let client = ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.lazyLoad(cacheRefreshIntervalInSeconds: 120), session: MockHTTP.session())
        let expectation1 = self.expectation(description: "wait for response")
        client.getValue(for: "fakeKey", defaultValue: "") { value in
            XCTAssertEqual("", value)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2)
    }

    func testGetAllValues() {
        MockHTTP.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        let client = createClient()
        let expectation1 = self.expectation(description: "wait for response")
        client.refresh {
            client.getAllValues { allValues in
                XCTAssertEqual(2, allValues.count)
                XCTAssertEqual(true, allValues["key1"] as! Bool)
                XCTAssertEqual(false, allValues["key2"] as! Bool)
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2)
    }

    private func createClient() -> ConfigCatClient {
        ConfigCatClient(sdkKey: "test", refreshMode: PollingModes.manualPoll(), session: MockHTTP.session())
    }
}
