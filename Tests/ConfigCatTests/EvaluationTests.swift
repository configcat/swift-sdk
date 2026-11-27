import XCTest
@testable import ConfigCat

class EvaluationTests: XCTestCase {
    lazy var testBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: type(of: self))
        #endif
    }()

    func testFlagValueFromAnyPreservesNumericTypes() throws {
        let json = #"[true, false, 0, 1, -1, 0.0, 1.0, 1.5, "text", null]"#
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any])
        let expected: [FlagValue?] = [
            .bool(true), .bool(false), .int(0), .int(1), .int(-1),
            .double(0), .double(1), .double(1.5), .string("text"), nil
        ]
        XCTAssertEqual(values.map { FlagValue.fromRaw(value: $0) }, expected)
        XCTAssertEqual(FlagValue.fromRaw(value: true), .bool(true))
        XCTAssertEqual(FlagValue.fromRaw(value: 1), .int(1))
        XCTAssertEqual(FlagValue.fromRaw(value: 1.0), .double(1))
        XCTAssertNil(FlagValue.fromRaw(value: NSNumber(value: UInt64.max)))
    }
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testUserSnapshotsUnsupportedAttributesWithoutChangingComparators() async {
        final class MutableValue: CustomStringConvertible {
            var description = "1"
        }

        let value = MutableValue()
        let user = ConfigCatUser(identifier: "id", custom: ["Custom1": value])
        value.description = "2"
        let snapshot = await Task.detached {
            user.attribute(for: "Custom1") as? String
        }.value
        XCTAssertEqual("1", snapshot)

        let json = #"""
        {"f":{
          "text":{"t":0,"v":{"b":false},"r":[{"c":[{"u":{"a":"Custom1","c":28,"s":"1"}}],"s":{"v":{"b":true}}}]},
          "number":{"t":0,"v":{"b":false},"r":[{"c":[{"u":{"a":"Custom1","c":10,"d":1}}],"s":{"v":{"b":true}}}]}
        }}
        """#
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: json, statusCode: 200))
        let logger = RecordingLogger()
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: engine).ensureStarted()
        await client.forceRefresh()

        let textResult = await client.getValue(for: "text", defaultValue: false, user: user)
        let numberResult = await client.getValue(for: "number", defaultValue: false, user: user)
        XCTAssertTrue(textResult)
        XCTAssertFalse(numberResult)
        XCTAssertTrue(logger.logs.contains { $0.contains("'1' is not a valid decimal number") })
    }

    func testUserPreservesSupportedAttributeTypes() {
        let mutableString = NSMutableString(string: "original")
        let mutableArray = NSMutableArray(array: ["original"])
        let user = ConfigCatUser(identifier: "id", custom: [
            "integer": Int8(7),
            "unsigned": UInt64.max,
            "float": Float(1.25),
            "date": Date(timeIntervalSince1970: 42),
            "array": ["a", "b"],
            "number": NSNumber(value: true),
            "decimal": NSDecimalNumber(string: "123.456"),
            "mutableString": mutableString,
            "mutableArray": mutableArray
        ])
        mutableString.setString("changed")
        mutableArray[0] = "changed"

        XCTAssertEqual(user.attribute(for: "integer") as? Int8, 7)
        XCTAssertEqual(user.attribute(for: "unsigned") as? UInt64, UInt64.max)
        XCTAssertEqual(user.attribute(for: "float") as? Float, 1.25)
        XCTAssertEqual(user.attribute(for: "date") as? Date, Date(timeIntervalSince1970: 42))
        XCTAssertEqual(user.attribute(for: "array") as? [String], ["a", "b"])
        XCTAssertEqual(user.attribute(for: "number") as? NSNumber, NSNumber(value: true))
        XCTAssertEqual(user.attribute(for: "decimal") as? NSDecimalNumber, NSDecimalNumber(string: "123.456"))
        XCTAssertEqual(user.attribute(for: "mutableString") as? String, "original")
        XCTAssertEqual(user.attribute(for: "mutableArray") as? [String], ["original"])
    }

    func testUserAttributeConversions() {
        let numbers: [(Any, String, Double)] = [
            (Int(-42), "-42", -42),
            (Int8(-8), "-8", -8),
            (Int16(-16), "-16", -16),
            (Int32(-32), "-32", -32),
            (Int64.min, "\(Int64.min)", Double(Int64.min)),
            (UInt(42), "42", 42),
            (UInt8(8), "8", 8),
            (UInt16(16), "16", 16),
            (UInt32(32), "32", 32),
            (UInt64.max, "\(UInt64.max)", Double(UInt64.max)),
            (Float(1.25), "1.25", 1.25),
            (Double(2.5), "2.5", 2.5),
            (NSNumber(value: true), "1", 1),
            (NSNumber(value: 0.1), "0.1", 0.1),
        ]
        for (value, text, number) in numbers {
            let attribute = UserAttribute(value)
            XCTAssertEqual(attribute.asString().0, text)
            XCTAssertTrue(attribute.asString().1)
            XCTAssertEqual(attribute.asDouble(), number)
        }

        XCTAssertEqual(UserAttribute(Float.infinity).asString().0, "Infinity")
        XCTAssertEqual(UserAttribute(-Double.infinity).asString().0, "-Infinity")
        XCTAssertEqual(UserAttribute(Double.nan).asString().0, "NaN")
        XCTAssertTrue(UserAttribute("NaN").asDouble()?.isNaN == true)
        XCTAssertEqual(UserAttribute(" 2,5 ").asDouble(), 2.5)
        XCTAssertEqual(UserAttribute(Date(timeIntervalSince1970: 42)).asDateDouble(), 42)
        XCTAssertNotNil(UserAttribute("1.2.3").asSemver())
        XCTAssertEqual(UserAttribute(#"["a","b"]"#).asSlice(), ["a", "b"])
        XCTAssertNil(UserAttribute(true).asDouble())
    }

    func testInvalidSettingValueSnapshotsDiagnostic() {
        final class MutableValue: CustomStringConvertible {
            var description = "original"
        }
        let value = MutableValue()
        let setting = SettingValue.fromAnyValue(value: value)
        value.description = "changed"

        guard case .error(let error) = setting.toCheckedValue(settingType: .unknown) else {
            return XCTFail("Expected an invalid setting error")
        }
        XCTAssertTrue(error.contains("Setting value 'original' is of an unsupported type (MutableValue"))
    }

    func testSegmentConditionsResolveDuringParsing() {
        let json: [String: Any] = [
            "s": [["n": "segment", "r": []]],
            "f": ["key": ["t": 0, "v": ["b": false], "r": [
                ["c": [["s": ["s": 0, "c": 0]]], "s": ["v": ["b": true]]],
                ["c": [["s": ["s": -1, "c": 0]]], "s": ["v": ["b": true]]],
            ]]]
        ]
        let rules = Config.fromJson(json: json).settings["key"]?.targetingRules
        XCTAssertEqual(rules?[0].conditions[0].segmentCondition?.segment?.name, "segment")
        XCTAssertNil(rules?[1].conditions[0].segmentCondition?.segment)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testPrerequisiteCircularDependencies() async {
        let tests = [
            ("key1", "'key1' -> 'key1'"),
            ("key2", "'key2' -> 'key3' -> 'key2'"),
            ("key4", "'key4' -> 'key3' -> 'key2' -> 'key3'"),
        ]
        
        guard let jsonContent = loadResource(bundle: testBundle, path: "json/test_circulardependency_v6.json") else {
            XCTFail()
            return
        }
        
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: jsonContent, statusCode: 200))
        
        for test in tests {
            let logger = RecordingLogger()
            let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: engine).ensureStarted()
            let _ = await client.getValue(for: test.0, defaultValue: "")
            
            XCTAssertTrue(logger.logs.last?.contains(test.1) ?? false)
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testPrerequisiteFlagComparisonValueTypeMismatch() async {
        let tests: [(String, String, Any?, Any?)] = [
            ("stringDependsOnBool", "mainBoolFlag", true, "Dog"),
            ("stringDependsOnBool", "mainBoolFlag", false, "Cat"),
            ("stringDependsOnBool", "mainBoolFlag", "1", nil),
            ("stringDependsOnBool", "mainBoolFlag", 1, nil),
            ("stringDependsOnBool", "mainBoolFlag", 1.0, nil),
            ("stringDependsOnBool", "mainBoolFlag", [true], nil),
            ("stringDependsOnBool", "mainBoolFlag", nil, nil),
            ("stringDependsOnString", "mainStringFlag", "private", "Dog"),
            ("stringDependsOnString", "mainStringFlag", "Private", "Cat"),
            ("stringDependsOnString", "mainStringFlag", true, nil),
            ("stringDependsOnString", "mainStringFlag", 1, nil),
            ("stringDependsOnString", "mainStringFlag", 1.0, nil),
            ("stringDependsOnString", "mainStringFlag", ["private"], nil),
            ("stringDependsOnString", "mainStringFlag", nil, nil),
            ("stringDependsOnInt", "mainIntFlag", 2, "Dog"),
            ("stringDependsOnInt", "mainIntFlag", 1, "Cat"),
            ("stringDependsOnInt", "mainIntFlag", "2", nil),
            ("stringDependsOnInt", "mainIntFlag", true, nil),
            ("stringDependsOnInt", "mainIntFlag", 2.0, nil),
            ("stringDependsOnInt", "mainIntFlag", [2], nil),
            ("stringDependsOnInt", "mainIntFlag", nil, nil),
            ("stringDependsOnDouble", "mainDoubleFlag", 0.1, "Dog"),
            ("stringDependsOnDouble", "mainDoubleFlag", 0.11, "Cat"),
            ("stringDependsOnDouble", "mainDoubleFlag", "0.1", nil),
            ("stringDependsOnDouble", "mainDoubleFlag", true, nil),
            ("stringDependsOnDouble", "mainDoubleFlag", 1, nil),
            ("stringDependsOnDouble", "mainDoubleFlag", [0.1], nil),
            ("stringDependsOnDouble", "mainDoubleFlag", nil, nil),
        ]
        
        for test in tests {
            let logger = RecordingLogger()
            let client = ConfigCatClient(sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg", pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: nil, flagOverrides: TestDictionaryDataSource(source: [test.1: test.2], behaviour: .localOverRemote)).ensureStarted()
            
            let res = await client.getValue(for: test.0, defaultValue: Optional<String>.none)
            
            XCTAssertTrue(anyEq(a: test.3, b: res))
            
            if test.3 == nil {
                let type = SettingValue.fromAnyValue(value: test.2).settingType
                if test.2 == nil {
                    XCTAssertTrue(logger.logs.last?.contains("Setting value is missing") ?? false, logger.logs.last ?? "")
                } else if type == .unknown {
                    XCTAssertTrue(logger.logs.last?.range(of: "Setting value '[^']+' is of an unsupported type", options: .regularExpression) != nil, logger.logs.last ?? "")
                } else {
                    XCTAssertTrue(logger.logs.last?.range(of: "Type mismatch between comparison value '[^']+' and prerequisite flag '[^']+'", options: .regularExpression) != nil)
                }
            }
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testPrerequisiteFlagOverrides() async {
        let tests: [(String, String, String, OverrideBehaviour?, String?)] = [
            ("stringDependsOnString", "1", "john@sensitivecompany.com", nil, "Dog"),
            ("stringDependsOnString", "1", "john@sensitivecompany.com", .remoteOverLocal, "Dog"),
            ("stringDependsOnString", "1", "john@sensitivecompany.com", .localOverRemote, "Dog"),
            ("stringDependsOnString", "1", "john@sensitivecompany.com", .localOnly, nil),
            ("stringDependsOnString", "2", "john@notsensitivecompany.com", nil, "Cat"),
            ("stringDependsOnString", "2", "john@notsensitivecompany.com", .remoteOverLocal, "Cat"),
            ("stringDependsOnString", "2", "john@notsensitivecompany.com", .localOverRemote, "Dog"),
            ("stringDependsOnString", "2", "john@notsensitivecompany.com", .localOnly, nil),
            ("stringDependsOnInt", "1", "john@sensitivecompany.com", nil, "Dog"),
            ("stringDependsOnInt", "1", "john@sensitivecompany.com", .remoteOverLocal, "Dog"),
            ("stringDependsOnInt", "1", "john@sensitivecompany.com", .localOverRemote, "Cat"),
            ("stringDependsOnInt", "1", "john@sensitivecompany.com", .localOnly, nil),
            ("stringDependsOnInt", "2", "john@notsensitivecompany.com", nil, "Cat"),
            ("stringDependsOnInt", "2", "john@notsensitivecompany.com", .remoteOverLocal, "Cat"),
            ("stringDependsOnInt", "2", "john@notsensitivecompany.com", .localOverRemote, "Dog"),
            ("stringDependsOnInt", "2", "john@notsensitivecompany.com", .localOnly, nil),
        ]
        
        guard let jsonContent = loadResource(bundle: testBundle, path: "json/test_override_flagdependency_v6.json") else {
            XCTFail()
            return
        }
        
        for test in tests {
            let logger = NoLogger()
            let source = test.3 != nil ? try! BundleResourceDataSource(json: jsonContent, behaviour: test.3!) : nil
            let client = ConfigCatClient(sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg", pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: nil, flagOverrides: source, logLevel: .info).ensureStarted()
            
            let user = ConfigCatUser(identifier: test.1, email: test.2)
            let res = await client.getValue(for: test.0, defaultValue: Optional<String>.none, user: user)
            
            XCTAssertTrue(anyEq(a: test.4, b: res))
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testMatchedEvaluationRuleAndPercantageOption() async {
        let tests: [(String, String, String?, String?, String?, String, Bool, Bool)] = [
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", nil, nil, nil, "Cat", false, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", nil, nil, "Cat", false, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "a@example.com", nil, "Dog", true, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "a@configcat.com", nil, "Cat", false, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "a@configcat.com", "", "Frog", true, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "a@configcat.com", "US", "Fish", true, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "b@configcat.com", nil, "Cat", false, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "b@configcat.com", "", "Falcon", false, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw", "stringMatchedTargetingRuleAndOrPercentageOption", "12345", "b@configcat.com", "US", "Spider", false, true),
        ]
        
        var clientCache: [String: ConfigCatClient] = [:]
        
        for test in tests {
            let logger = NoLogger()
            var client = clientCache[test.0]
            if client == nil {
                client = ConfigCatClient(sdkKey: test.0, pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: nil).ensureStarted()
                clientCache[test.0] = client
            }
            
            let user = test.2 != nil ? ConfigCatUser(identifier: test.2!, email: test.3, custom: test.4 == nil ? nil : ["PercentageBase": test.4!]) : nil
            let res = await client!.getValueDetails(for: test.1, defaultValue: Optional<String>.none, user: user)
            
            XCTAssertTrue(anyEq(a: test.5, b: res.value), "\(test.5) is not equal to \(String(describing: res.value))")
            XCTAssertEqual(test.6, res.matchedTargetingRule != nil)
            XCTAssertEqual(test.7, res.matchedPercentageOption != nil)
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testObjectAttributeValueConversion() async {
        let logger = RecordingLogger()
        let client = ConfigCatClient(sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: nil).ensureStarted()
        
        let user = ConfigCatUser(identifier: "12345", custom: ["Custom1": 42])
        let _ = await client.getValueDetails(for: "boolTextEqualsNumber", defaultValue: Optional<Bool>.none, user: user)
        
        XCTAssertTrue(logger.logs.last?.contains("Evaluation of condition (User.Custom1 EQUALS '42') for setting 'boolTextEqualsNumber' may not produce the expected result (the User.Custom1 attribute is not a string value, thus it was automatically converted to the string value '42'). Please make sure that using a non-string value was intended.") ?? false)
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testUserObjectAttributeValueConversion() async {
        let tests: [(String, String, String, String, Any, Any)] = [
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", "0.0", "20%"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", "0.9.9", "< 1.0.0"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", "1.0.0", "20%"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", "1.1", "20%"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", 0, "20%"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", 0.9, "20%"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg", "lessThanWithPercentage", "12345", "Custom1", 2, "20%"),
            // Number-based comparisons
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int8(-1), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int8(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int8(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int8(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt8(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt8(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt8(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt16(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt16(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt16(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", -1, "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", 2, "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", 3, "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", 5, ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int64.min, "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int64(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int64(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int64(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Int64.max, ">5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt64(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt64(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt64(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", UInt64.max, ">5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", -Float.infinity, "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float32(-1), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float32(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float32(2.1), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float32(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float32(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float.infinity, ">5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Float.nan, "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", -Double.infinity, "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double(-1), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double(2), "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double(2.1), "<=2,1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double(3), "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double(5), ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double.infinity, ">5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", Double.nan, "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "-Infinity", "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "-1", "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "2", "<2.1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "2.1", "<=2,1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "2,1", "<=2,1"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "3", "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "5", ">=5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "Infinity", ">5"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "NaN", "<>4.2"),
            ("configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw", "numberWithPercentage", "12345", "Custom1", "NaNa", "80%"),
            // Date time-based comparisons
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDate(val: "2023-03-31T23:59:59.999Z"), false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDateTZ(val: "2023-04-01T01:59:59.999+02:00"), false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDate(val: "2023-04-01T00:00:00.001Z"), true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDateTZ(val: "2023-04-01T02:00:00.0010000+02:00"), true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDate(val: "2023-04-30T23:59:59.999Z"), true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDateTZ(val: "2023-05-01T01:59:59.999+02:00"), true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDate(val: "2023-05-01T00:00:00.001Z"), false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", parseDateTZ(val: "2023-05-01T02:00:00.001+02:00"), false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", -Double.infinity, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1680307199.999, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1680307200.001, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1682899199.999, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1682899200.001, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", Double.infinity, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", Double.nan, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1680307199, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1680307201, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1682899199, true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", 1682899201, false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "-Infinity", false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "1680307199.999", false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "1680307200.001", true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "1682899199.999", true),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "1682899200.001", false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "+Infinity", false),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "boolTrueIn202304", "12345", "Custom1", "NaN", false),
            // String array-based comparisons
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat", "12345", "Custom1", ["x", "read"], "Dog"),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat", "12345", "Custom1", ["x", "Read"], "Cat"),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat", "12345", "Custom1", "[\"x\", \"read\"]", "Dog"),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat", "12345", "Custom1", "[\"x\", \"Read\"]", "Cat"),
            ("configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ", "stringArrayContainsAnyOfDogDefaultCat", "12345", "Custom1", "x, read", "Cat"),
        ]
        
        var clientCache: [String: ConfigCatClient] = [:]
        
        for test in tests {
            let logger = NoLogger()
            var client = clientCache[test.0]
            if client == nil {
                client = ConfigCatClient(sdkKey: test.0, pollingMode: PollingModes.autoPoll(), logger: logger, httpEngine: nil).ensureStarted()
                clientCache[test.0] = client
            }
            
            let user = ConfigCatUser(identifier: test.2,  custom: [test.3: test.4])
            if let expected = test.5 as? Bool {
                let res = await client!.getValue(for: test.1, defaultValue: Optional<Bool>.none, user: user)
                XCTAssertEqual(expected, res)
            } else if let expected = test.5 as? String {
                let res = await client!.getValue(for: test.1, defaultValue: Optional<String>.none, user: user)
                XCTAssertEqual(expected, res)
            } else {
                XCTFail("Unexpected expected value type: \(type(of: test.5))")
            }
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testComparisonAttributeConversionToCanonicalStringRepresentation() async {
        let tests: [(String, Any, String)] = [
            ("numberToStringConversion", 0.12345, "1"),
            ("numberToStringConversionInt", Int8(125), "4"),
            ("numberToStringConversionInt", UInt8(125), "4"),
            ("numberToStringConversionInt", Int8(125), "4"),
            ("numberToStringConversionInt", UInt16(125), "4"),
            ("numberToStringConversionInt", 125, "4"),
            ("numberToStringConversionInt", UInt(125), "4"),
            ("numberToStringConversionInt", Int64(125), "4"),
            ("numberToStringConversionInt", UInt64(125), "4"),
            ("numberToStringConversionPositiveExp", -1.23456789e96, "2"),
            ("numberToStringConversionNegativeExp", -12345.6789E-100, "4"),
            ("numberToStringConversionNaN", Double.nan, "3"),
            ("numberToStringConversionPositiveInf", Double.infinity, "4"),
            ("numberToStringConversionNegativeInf", -Double.infinity, "3"),
            ("dateToStringConversion", parseDate(val: "2023-03-31T23:59:59.999Z"), "3"),
            ("dateToStringConversion", 1680307199.999, "3"),
            ("dateToStringConversionNaN", Double.nan, "3"),
            ("dateToStringConversionPositiveInf", Double.infinity, "1"),
            ("dateToStringConversionNegativeInf", -Double.infinity, "5"),
            ("stringArrayToStringConversion", ["read", "Write", " eXecute "], "4"),
            ("stringArrayToStringConversionEmpty", [String](), "5"),
            //("stringArrayToStringConversionSpecialChars", ["+<>%\"'\\/\t\r\n"], "3"), We'll fix this with the .withoutEscapingSlashes JSONEncoder option after macOS 10.15
            ("stringArrayToStringConversionUnicode", ["äöüÄÖÜçéèñışğâ¢™✓😀"], "2")
        ]
        
        guard let jsonContent = loadResource(bundle: testBundle, path: "json/comparison_attribute_conversion.json") else {
            XCTFail()
            return
        }
        
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: jsonContent, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        for test in tests {
            let user = ConfigCatUser(identifier: "12345", custom: ["Custom1": test.1])
            let res = await client.getValue(for: test.0, defaultValue: "default", user: user)
            
            XCTAssertEqual(test.2, res, "\(test.0) \(test.1)")
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSpecialCharacters() async {
        let tests: [(String, String, String)] = [
            ("specialCharacters", "äöüÄÖÜçéèñışğâ¢™✓😀", "äöüÄÖÜçéèñışğâ¢™✓😀"),
            ("specialCharactersHashed", "äöüÄÖÜçéèñışğâ¢™✓😀", "äöüÄÖÜçéèñışğâ¢™✓😀"),
        ]
        
        let client = ConfigCatClient(sdkKey: "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/u28_1qNyZ0Wz-ldYHIU7-g", pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: nil).ensureStarted()
        
        
        for test in tests {
            let res = await client.getValue(for: test.0, defaultValue: "NOT_CAT", user: ConfigCatUser(identifier: test.1))
            
            XCTAssertTrue(anyEq(a: test.2, b: res))
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testComparisonAttributeTrimming() async {
        let tests: [(String, String)] = [
            ("isoneof", "no trim"),
            ("isnotoneof", "no trim"),
            ("isoneofhashed", "no trim"),
            ("isnotoneofhashed", "no trim"),
            ("equalshashed", "no trim"),
            ("notequalshashed", "no trim"),
            ("arraycontainsanyofhashed", "no trim"),
            ("arraynotcontainsanyofhashed", "no trim"),
            ("equals", "no trim"),
            ("notequals", "no trim"),
            ("startwithanyof", "no trim"),
            ("notstartwithanyof", "no trim"),
            ("endswithanyof", "no trim"),
            ("notendswithanyof", "no trim"),
            ("arraycontainsanyof", "no trim"),
            ("arraynotcontainsanyof", "no trim"),
            ("startwithanyofhashed", "no trim"),
            ("notstartwithanyofhashed", "no trim"),
            ("endswithanyofhashed", "no trim"),
            ("notendswithanyofhashed", "no trim"),
            ("semverisoneof", "4 trim"),
            ("semverisnotoneof", "5 trim"),
            ("semverless", "6 trim"),
            ("semverlessequals", "7 trim"),
            ("semvergreater", "8 trim"),
            ("semvergreaterequals", "9 trim"),
            ("numberequals", "10 trim"),
            ("numbernotequals", "11 trim"),
            ("numberless", "12 trim"),
            ("numberlessequals", "13 trim"),
            ("numbergreater", "14 trim"),
            ("numbergreaterequals", "15 trim"),
            ("datebefore", "18 trim"),
            ("dateafter", "19 trim"),
            ("containsanyof", "no trim"),
            ("notcontainsanyof", "no trim"),
        ]
        
        guard let jsonContent = loadResource(bundle: testBundle, path: "json/comparison_attribute_trimming.json") else {
            XCTFail()
            return
        }
        
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: jsonContent, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        for test in tests {
            let user = ConfigCatUser(identifier: " 12345 ", country: "[\" USA \"]", custom: ["Version": " 1.0.0 ", "Number": " 3 ", "Date": " 1705253400 "])
            let res = await client.getValue(for: test.0, defaultValue: "default", user: user)
            
            XCTAssertEqual(test.1, res)
        }
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testComparisonValueTrimming() async {
        let tests: [(String, String)] = [
            ("isoneof", "no trim"),
            ("isnotoneof", "no trim"),
            ("containsanyof", "no trim"),
            ("notcontainsanyof", "no trim"),
            ("isoneofhashed", "no trim"),
            ("isnotoneofhashed", "no trim"),
            ("equalshashed", "no trim"),
            ("notequalshashed", "no trim"),
            ("arraycontainsanyofhashed", "no trim"),
            ("arraynotcontainsanyofhashed", "no trim"),
            ("equals", "no trim"),
            ("notequals", "no trim"),
            ("startwithanyof", "no trim"),
            ("notstartwithanyof", "no trim"),
            ("endswithanyof", "no trim"),
            ("notendswithanyof", "no trim"),
            ("arraycontainsanyof", "no trim"),
            ("arraynotcontainsanyof", "no trim"),
            ("startwithanyofhashed", "no trim"),
            ("notstartwithanyofhashed", "no trim"),
            ("endswithanyofhashed", "no trim"),
            ("notendswithanyofhashed", "no trim"),
            ("semverisoneof", "4 trim"),
            ("semverisnotoneof", "5 trim"),
            ("semverless", "6 trim"),
            ("semverlessequals", "7 trim"),
            ("semvergreater", "8 trim"),
            ("semvergreaterequals", "9 trim"),
        ]
        
        guard let jsonContent = loadResource(bundle: testBundle, path: "json/comparison_value_trimming.json") else {
            XCTFail()
            return
        }
        
        let engine = MockEngine()
        engine.enqueueResponse(response: Response(body: jsonContent, statusCode: 200))
        let client = ConfigCatClient(sdkKey: randomSdkKey(), pollingMode: PollingModes.autoPoll(), logger: NoLogger(), httpEngine: engine).ensureStarted()
        
        for test in tests {
            let user = ConfigCatUser(identifier: "12345", country: "[\"USA\"]", custom: ["Version": "1.0.0", "Number": "3", "Date": "1705253400"])
            let res = await client.getValue(for: test.0, defaultValue: "default", user: user)
            
            XCTAssertEqual(test.1, res, "\(test.0) \(test.1)")
        }
    }
    #endif
}
