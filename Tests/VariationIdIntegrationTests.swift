import XCTest
import ConfigCat

class VariationIdIntegrationTests: XCTestCase {
    lazy var testBundle: Bundle = {
        return Bundle(for: type(of: self))
    }()
    
    func testVariatonIdMatrix() throws {
        guard let url = testBundle.url(forResource: "testmatrix_variationId", withExtension: "csv") else {
            XCTFail()
            return
        }

        let client: ConfigCatClient = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/nQ5qkhRAUEa6beEyyrVLBA")
        
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
            
            var user: User? = nil
            if !testObjects[0].isEmpty && testObjects[0] != "##null##" {
                
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
                
                user = User(identifier: identifier, email: email, country: country, custom: custom)
            }
            
            var i: Int = 0
            for settingKey in settingKeys {
                if let actualValue: String = client.getVariationId(for: settingKey, defaultVariationId: "", user: user) {
                    let expectedValue = testObjects[i + 4]
                    if actualValue != expectedValue {
                        errors.append(String(format: "Identifier: %@, Key: %@. Expected: %@, Result: %@", testObjects[0], settingKey, expectedValue, actualValue))
                    }

                    i += 1
                    continue
                }


                XCTFail()
            }
        }
            
        XCTAssertEqual(0, errors.count)
        return
    }
}
