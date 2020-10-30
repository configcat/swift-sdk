import XCTest
import ConfigCat

class RolloutIntegrationTests: XCTestCase {
    enum TestType {
        case value
        case variation
    }

    lazy var testBundle: Bundle = {
        return Bundle(for: type(of: self))
    }()
    
    func testRolloutMatrixText() throws {
        if let url = testBundle.url(forResource: "testmatrix", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixSemantic() throws {
        if let url = testBundle.url(forResource: "testmatrix_semantic", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/BAr3KgLTP0ObzKnBTo5nhA", type: .value)
        } else {
            XCTFail()
        }
    }
    
    func testRolloutMatrixSemantic2() throws {
        if let url = testBundle.url(forResource: "testmatrix_semantic_2", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixNumber() throws {
        if let url = testBundle.url(forResource: "testmatrix_number", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/uGyK3q9_ckmdxRyI7vjwCw", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixSensitive() throws {
        if let url = testBundle.url(forResource: "testmatrix_sensitive", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/qX3TP2dTj06ZpCCT1h_SPA", type: .value)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrixVariationId() throws {
        if let url = testBundle.url(forResource: "testmatrix_variationId", withExtension: "csv") {
            try testRolloutMatrix(url: url, sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/nQ5qkhRAUEa6beEyyrVLBA", type: .variation)
        } else {
            XCTFail()
        }
    }

    func testRolloutMatrix(url: URL, sdkKey: String, type: TestType) throws {
        let client: ConfigCatClient = ConfigCatClient(sdkKey: sdkKey)
        
        guard let matrixData = try? Data(contentsOf: url), let content = String(bytes: matrixData, encoding: .utf8) else {
            XCTFail()
            return
        }
            
        let rows = content.components(separatedBy: "\n")
            .map{ row in row.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)}
        
        let header = rows[0].components(separatedBy: ";")
        
        let customKey = header[3]
        
        let settingKeys = header
            .map{ key in key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)}
            .skip(count: 4)
        
        var errors: [String] = []
        for i in 1..<rows.count {
            let testObjects = rows[i].components(separatedBy: ";")
                .map{ key in key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)}
            
            if testObjects.count == 1 {
                continue
            }
            
            var user: ConfigCatUser? = nil
            if testObjects[0] != "##null##" {
                
                var email = ""
                var country = ""
                
                let identifier = testObjects[0]
                
                if !testObjects[1].isEmpty && testObjects[1] != "##null##" {
                    email = testObjects[1]
                }
                
                if !testObjects[2].isEmpty && testObjects[2] != "##null##" {
                    country = testObjects[2]
                }
                
                var custom: [String: String] = [:]
                if !testObjects[3].isEmpty && testObjects[3] != "##null##" {
                    custom[customKey] = testObjects[3]
                }
                
                user = ConfigCatUser(identifier: identifier, email: email, country: country, custom: custom)
            }
            
            var i: Int = 0
            for settingKey in settingKeys {
                if type == .value {
                    if let anyValue: Any = client.getValue(for: settingKey, defaultValue: nil, user: user) {
                        if let boolValue = anyValue as? Bool,
                            let expectedValue = Bool(testObjects[i + 4].lowercased()) {
                            if boolValue != expectedValue {
                                errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, boolValue))
                            }
                            
                            i += 1
                            continue
                        }
                        
                        if let intValue = anyValue as? Int,
                            let expectedValue = Int(testObjects[i + 4]) {
                            if intValue != expectedValue {
                                errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, intValue))
                            }
                            
                            i += 1
                            continue
                        }
                        
                        if let doubleValue = anyValue as? Double,
                            let expectedValue = Double(testObjects[i + 4]) {
                            if doubleValue != expectedValue {
                                errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, doubleValue))
                            }
                            
                            i += 1
                            continue
                        }
                        
                        if let stringValue = anyValue as? String {
                            let expectedValue = testObjects[i + 4]
                            if stringValue != expectedValue {
                                errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, stringValue))
                            }
                            
                            i += 1
                            continue
                        }
                    }
                } else {
                    if let stringValue: String = client.getVariationId(for: settingKey, defaultVariationId: "", user: user) {
                            let expectedValue = testObjects[i + 4]
                            if stringValue != expectedValue {
                                errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, stringValue))
                            }
                            
                            i += 1
                            continue
                    }
                }
                
                XCTFail()
            }
        }
            
        XCTAssertEqual(0, errors.count)
        return
    }
}

extension Array {
    func skip(count:Int) -> [Element] { return [Element](self[count..<self.count]) }
}
