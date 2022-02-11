import XCTest
@testable import ConfigCat

class LocalTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": %@, "p": [], "r": [] } } }"#

    func testDictionary() throws {
        let dictionary:[String: Any] = [
            "enabledFeature": true,
            "disabledFeature": false,
            "intSetting": 5,
            "doubleSetting": 3.14,
            "stringSetting": "test"
        ]
        let client = ConfigCatClient(sdkKey: "testKey", flagOverrides: LocalDictionaryDataSource(source: dictionary, behaviour: .localOnly))

        XCTAssertTrue(client.getValue(for: "enabledFeature", defaultValue: false));
        XCTAssertFalse(client.getValue(for: "disabledFeature", defaultValue: true));
        XCTAssertEqual(5, client.getValue(for: "intSetting", defaultValue: 0));
        XCTAssertEqual(3.14, client.getValue(for: "doubleSetting", defaultValue: 0.0));
        XCTAssertEqual("test", client.getValue(for: "stringSetting", defaultValue: ""));
    }

    func testLocalOverRemote() throws {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "false"), statusCode: 200))

        let dictionary:[String: Any] = [
            "fakeKey": true,
            "nonexisting": true
        ]
        let client = ConfigCatClient(sdkKey: "testKey", refreshMode: PollingModes.manualPoll(), session: mockSession, flagOverrides: LocalDictionaryDataSource(source: dictionary, behaviour: .localOverRemote))
        client.refresh()

        XCTAssertTrue(client.getValue(for: "fakeKey", defaultValue: false));
        XCTAssertTrue(client.getValue(for: "nonexisting", defaultValue: false));
    }

    func testRemoteOverLocal() throws {
        let mockSession = MockURLSession()
        mockSession.enqueueResponse(response: Response(body: String(format: self.testJsonFormat, "false"), statusCode: 200))

        let dictionary:[String: Any] = [
            "fakeKey": true,
            "nonexisting": true
        ]
        let client = ConfigCatClient(sdkKey: "testKey", refreshMode: PollingModes.manualPoll(), session: mockSession, flagOverrides: LocalDictionaryDataSource(source: dictionary, behaviour: .remoteOverLocal))
        client.refresh()

        XCTAssertFalse(client.getValue(for: "fakeKey", defaultValue: true));
        XCTAssertTrue(client.getValue(for: "nonexisting", defaultValue: false));
    }
}
