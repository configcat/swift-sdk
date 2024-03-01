import XCTest
@testable import ConfigCat

class LocalTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "t": 0, "v": { "b": %@ } } } }"#

    func testDictionary() throws {
        let dictionary: [String: Any] = [
            "enabledFeature": true,
            "disabledFeature": false,
            "intSetting": 5,
            "doubleSetting": 3.14,
            "stringSetting": "test"
        ]
        let options = ConfigCatOptions.default
        options.flagOverrides = LocalDictionaryDataSource(source: dictionary, behaviour: .localOnly)
        let client = ConfigCatClient.get(sdkKey: "testKey", options: options)
        let expectation = self.expectation(description: "wait for response")
        client.getAllValues { values in
            XCTAssertTrue(values["enabledFeature"] as? Bool ?? false)
            XCTAssertFalse(values["disabledFeature"] as? Bool ?? true)
            XCTAssertEqual(5, values["intSetting"] as? Int ?? 0)
            XCTAssertEqual(3.14, values["doubleSetting"] as? Double ?? 0.0)
            XCTAssertEqual("test", values["stringSetting"] as? String ?? "")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testLocalOverRemote() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "false"), statusCode: 200))

        let dictionary: [String: Any] = [
            "fakeKey": true,
            "nonexisting": true
        ]
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: Hooks(), flagOverrides: LocalDictionaryDataSource(source: dictionary, behaviour: .localOverRemote))
        let expectation = self.expectation(description: "wait for response")
        client.getAllValues { values in
            XCTAssertTrue(values["fakeKey"] as? Bool ?? false)
            XCTAssertTrue(values["nonexisting"] as? Bool ?? false)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testRemoteOverLocal() throws {
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: String(format: testJsonFormat, "false"), statusCode: 200))

        let dictionary: [String: Any] = [
            "fakeKey": true,
            "nonexisting": true
        ]
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine, hooks: Hooks(), flagOverrides: LocalDictionaryDataSource(source: dictionary, behaviour: .remoteOverLocal))
        let expectation = self.expectation(description: "wait for response")
        client.getAllValues { values in
            XCTAssertFalse(values["fakeKey"] as? Bool ?? true)
            XCTAssertTrue(values["nonexisting"] as? Bool ?? false)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}
