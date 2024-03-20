import XCTest
@testable import ConfigCat

class EvaluationLogTests: XCTestCase {
    lazy var testBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: type(of: self))
        #endif
    }()
    
    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func test1TargetingRule() async {
        await runEvalLogTest(suiteName: "1_targeting_rule")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func test2TargetingRules() async {
        await runEvalLogTest(suiteName: "2_targeting_rules")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAndRules() async {
        await runEvalLogTest(suiteName: "and_rules")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testComparators() async {
        await runEvalLogTest(suiteName: "comparators")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testDateValidation() async {
        await runEvalLogTest(suiteName: "epoch_date_validation")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testListTruncation() async {
        await runEvalLogTest(suiteName: "list_truncation")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testNumberValidation() async {
        await runEvalLogTest(suiteName: "number_validation")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOptionsAfterTargetingRule() async {
        await runEvalLogTest(suiteName: "options_after_targeting_rule")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOptionsOnCustomAttr() async {
        await runEvalLogTest(suiteName: "options_based_on_custom_attr")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOptionsOnUserId() async {
        await runEvalLogTest(suiteName: "options_based_on_user_id")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testOptionsWithinTargetingRule() async {
        await runEvalLogTest(suiteName: "options_within_targeting_rule")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testPrerequisiteFlag() async {
        await runEvalLogTest(suiteName: "prerequisite_flag")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSegment() async {
        await runEvalLogTest(suiteName: "segment")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSemverValidation() async {
        await runEvalLogTest(suiteName: "semver_validation")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testSimpleValue() async {
        await runEvalLogTest(suiteName: "simple_value")
    }
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func runEvalLogTest(suiteName: String) async {
        guard let jsonContent = loadResource(bundle: testBundle, path: "evaluationlog/" + suiteName + ".json") else {
            XCTFail()
            return
        }
        guard let suite = TestSuite.fromJsonString(json: jsonContent) else {
            XCTFail()
            return
        }
        let logger = RecordingLogger()
        var localSource: OverrideDataSource?
        if let override = suite.override {
            guard let overrideJson = loadResource(bundle: testBundle, path: "evaluationlog/_overrides/" + override) else {
                XCTFail()
                return
            }
            localSource = try! BundleResourceDataSource(json: overrideJson, behaviour: .localOnly)
        }
        let client = ConfigCatClient(sdkKey: suite.sdkKey ?? randomSdkKey(), pollingMode: PollingModes.manualPoll(), logger: logger, httpEngine: nil, flagOverrides: localSource, logLevel: .info)
        await client.forceRefresh()
        
        for test in suite.tests {
            logger.reset()
            guard let expLogContent = loadResource(bundle: testBundle, path: "evaluationlog/" + suiteName + "/" + test.expectedLog) else {
                XCTFail()
                return
            }
            let user = test.user == nil ? nil : ConfigCatUser(custom: test.user!)
            let res = await client.getAnyValue(for: test.key, defaultValue: test.defaultVal, user: user)
            
            let exp = (test.user?.count ?? 0) > 1 ? expLogContent.removeTrailingNewLine().trimUserSection() : expLogContent.removeTrailingNewLine()
            let logs = (test.user?.count ?? 0) > 1 ? logger.entries.joined(separator: "\n").trimUserSection() : logger.entries.joined(separator: "\n")
            
            XCTAssertTrue(Utils.anyEq(a: test.returnVal, b: res), "\(test.returnVal) is not equal to \(res ?? "invalid")")
            XCTAssertEqual(exp, logs)
        }
    }
    #endif
}

class TestCase {
    let key: String
    let defaultVal: Any
    let returnVal: Any
    let expectedLog: String
    let user: [String: Any]?
    
    init(key: String, defaultVal: Any, returnVal: Any, expectedLog: String, user: [String : Any]?) {
        self.key = key
        self.defaultVal = defaultVal
        self.returnVal = returnVal
        self.expectedLog = expectedLog
        self.user = user
    }
    
    static func fromJson(json: [String: Any]) -> TestCase {
        TestCase(key: json["key"] as? String ?? "",
                 defaultVal: json["defaultValue"] as Any,
                 returnVal: json["returnValue"] as Any,
                 expectedLog: json["expectedLog"] as? String ?? "",
                 user: json["user"] as? [String : Any])
    }
}

class TestSuite {
    let configUrl: String
    let sdkKey: String?
    let override: String?
    let tests: [TestCase]
    
    init(configUrl: String, sdkKey: String?, override: String?, tests: [TestCase]) {
        self.configUrl = configUrl
        self.sdkKey = sdkKey
        self.override = override
        self.tests = tests
    }
    
    static func fromJsonString(json: String) -> TestSuite? {
        do {
            guard let data = json.data(using: .utf8) else {
                return nil
            }
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return nil
            }
            return .fromJson(json: jsonObject)
        } catch {
            return nil
        }
    }
    
    static func fromJson(json: [String: Any]) -> TestSuite {
        let testsMap = json["tests"] as? [[String: Any]] ?? []
        return TestSuite(configUrl: json["configUrl"] as? String ?? "",
                         sdkKey: json["sdkKey"] as? String,
                         override: json["jsonOverride"] as? String,
                         tests: testsMap.map { testCase in
            return TestCase.fromJson(json: testCase)
        })
    }
}

extension String {
    func trimUserSection() -> String {
        if let range = self.range(of: "for User") {
            let rest = self[range.upperBound...]
            if let newLineIndex = rest.firstIndex(of: "\n") {
                var copy = String(self)
                copy.removeSubrange(range.lowerBound..<newLineIndex)
                return copy
            }
        }
        return self
    }
}
