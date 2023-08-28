import XCTest
@testable import ConfigCat

class SnapshotTests: XCTestCase {
    let testJsonMultiple = #"{ "f": { "key1": { "v": true, "i": "fakeId1", "p": [], "r": [] }, "key2": { "v": false, "i": "fakeId2", "p": [], "r": [{"o":1,"a":"Email","t":2,"c":"@example.com","v":true,"i":"9f21c24c"}] } } }"#
    let user = ConfigCatUser(identifier: "id", email: "test@example.com")

    func testGetValue() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
        
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let value = snapshot.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = snapshot.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }

    func testGetAllKeys() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))
       
        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let keys = snapshot.getAllKeys()
        XCTAssertEqual(2, keys.count)
    }


    func testDetails() {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        let expectation = self.expectation(description: "wait for ready")
        client.hooks.addOnReady { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        
        let snapshot = client.snapshot()
        let details = snapshot.getValueDetails(for: "key2", defaultValue: true)
        XCTAssertFalse(details.isDefaultValue)
        XCTAssertFalse(details.value)
        XCTAssertEqual(1, engine.requests.count)
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testGetValueWait() async {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: testJsonMultiple, statusCode: 200))

        let client = ConfigCatClient(sdkKey: "test", pollingMode: PollingModes.autoPoll(), httpEngine: engine)
        
        await client.waitForReady()
        
        let snapshot = client.snapshot()
        let value = snapshot.getValue(for: "key1", defaultValue: false)
        XCTAssertTrue(value)
        let value2 = snapshot.getValue(for: "key2", defaultValue: false, user: user)
        XCTAssertTrue(value2)
    }
    #endif
}
