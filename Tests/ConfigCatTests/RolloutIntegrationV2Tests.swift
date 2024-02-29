import XCTest
@testable import ConfigCat

class RolloutIntegrationV2Tests: XCTestCase {
    enum TestType {
        case value
        case variation
    }

    lazy var testBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: type(of: self))
        #endif
    }()

    func testRolloutMatrixText() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/AG6C1ngVb0CvM07un6JisQ", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixSegmentsOld() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_segments_old.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/y_ZB7o-Xb0Swxth-ZlMSeA", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixSemantic() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_semantic.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixSemantic2() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_semantic_2.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/U8nt3zEhDEO5S2ulubCopA", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixNumber() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_number.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixSensitive() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_sensitive.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/-0YmVOUNgEGKkgRF-rU65g", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixVariationId() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_variationid.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/spQnkRTIPEWVivZkWM84lQ", type: .variation)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixAndOr() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_and_or.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/ByMO9yZNn02kXcm72lnY1A", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixCompV6() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_comparators_v6.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixPrerequisite() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_prerequisite_flag.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixSegments() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_segments.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/h99HYXWWNE2bH8eWyLAVMA", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixUnicode() {
        if let content = loadResource(bundle: testBundle, path: "testmatrix_unicode.csv") {
            testRolloutMatrix(content: content, sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/Da6w8dBbmUeMUBhh0iEeQQ", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrix(content: String, sdkKey: String, type: TestType) {
        let client: ConfigCatClient = ConfigCatClient.get(sdkKey: sdkKey) { options in
            options.pollingMode = PollingModes.lazyLoad()
            options.logLevel = .nolog
        }
        defer {
            ConfigCatClient.closeAll()
        }

        let rows = content.components(separatedBy: "\n")
                .map { row in
                    row.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }

        let header = rows[0].components(separatedBy: ";")

        let customKey = header[3]

        let settingKeys = header
                .map { key in
                    key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
                .skip(count: 4)

        var errors: [String] = []
        for k in 1..<rows.count {
            let testObjects = rows[k].components(separatedBy: ";")
                    .map { key in
                        key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    }

            if testObjects.count == 1 {
                continue
            }

            var user: ConfigCatUser? = nil
            if testObjects[0] != "##null##" {

                var email: String? = nil
                var country: String? = nil

                let identifier = testObjects[0]

                if !testObjects[1].isEmpty && testObjects[1] != "##null##" {
                    email = testObjects[1]
                }

                if !testObjects[2].isEmpty && testObjects[2] != "##null##" {
                    country = testObjects[2]
                }

                var custom: [String: Any] = [:]
                if !testObjects[3].isEmpty && testObjects[3] != "##null##" {
                    custom[customKey] = testObjects[3]
                }

                user = ConfigCatUser(identifier: identifier, email: email, country: country, custom: custom)
            }
            
            var i: Int = 0
            for settingKey in settingKeys {
                let expectation = expectation(description: "wait for response")
                if type == .value {
                    client.getValue(for: settingKey, defaultValue: nil, user: user) { (anyValue: Any?) in
                        if let boolValue = anyValue as? Bool,
                           let expectedValue = Bool(testObjects[i + 4].lowercased()) {
                            if boolValue != expectedValue {
                                errors.append("Identifier: \(testObjects[0]), Key: \(settingKey). Expected: \(expectedValue), Result: \(boolValue)")
                            }
                        } else if let intValue = anyValue as? Int,
                           let expectedValue = Int(testObjects[i + 4]) {
                            if intValue != expectedValue {
                                errors.append("Identifier: \(testObjects[0]), Key: \(settingKey). Expected: \(expectedValue), Result: \(intValue)")
                            }
                        } else if let doubleValue = anyValue as? Double,
                           let expectedValue = Double(testObjects[i + 4]) {
                            if doubleValue != expectedValue {
                                errors.append("Identifier: \(testObjects[0]), Key: \(settingKey). Expected: \(expectedValue), Result: \(doubleValue)")
                            }
                        } else if let stringValue = anyValue as? String {
                            let expectedValue = testObjects[i + 4]
                            if stringValue != expectedValue {
                                errors.append("Identifier: \(testObjects[0]), Key: \(settingKey). Expected: \(expectedValue), Result: \(stringValue)")
                            }
                        }
                        expectation.fulfill()
                    }
                } else {
                    client.getValueDetails(for: settingKey, defaultValue: nil, user: user) { (details: TypedEvaluationDetails<Any?>) in
                        let expectedValue = testObjects[i + 4]
                        if details.variationId != expectedValue {
                            errors.append("Identifier: \(testObjects[0]), Key: \(settingKey). Expected: \(expectedValue), Result: \(details.variationId ?? "")")
                        }
                        expectation.fulfill()
                    }
                }
                wait(for: [expectation], timeout: 20)
                i += 1
            }
        }
        
        if !errors.isEmpty {
            for err in errors {
                print(err)
            }
        }
        
        XCTAssertEqual(0, errors.count)
    }
}
