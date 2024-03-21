import Foundation

public class LocalDictionaryDataSource: OverrideDataSource {
    private var settings: [String: Setting] = [:]

    @objc public init(source: [String: Any], behaviour: OverrideBehaviour) {
        super.init(behaviour: behaviour)
        for (key, value) in source {
            settings[key] = Setting.fromAnyValue(value: value)
        }
    }

    public override func getOverrides() -> [String: Setting] {
        settings
    }
}
