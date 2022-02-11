import Foundation

public class LocalDictionaryDataSource: OverrideDataSource {
    private var settings: [String: Any] = [:]

    init(source: [String: Any], behaviour: OverrideBehaviour) {
        super.init(behaviour: behaviour)
        for (key, value) in source {
            settings[key] = [Config.value: value]
        }
    }

    public override func getOverrides() -> [String: Any] {
        return settings
    }
}
