import Foundation

public class LocalDictionaryDataSource: OverrideDataSource {
    private var settings: [String: Setting] = [:]

    @objc public init(source: [String: Any], behaviour: OverrideBehaviour) {
        super.init(behaviour: behaviour)
        for (key, value) in source {
            settings[key] = Setting(value: value, variationId: "", percentageItems: [], rolloutRules: [])
        }
    }

    public override func getOverrides() -> [String: Setting] {
        settings
    }
}
