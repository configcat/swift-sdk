import Foundation

public final class LocalDictionaryDataSource: OverrideDataSource {
    public let behaviour: OverrideBehaviour
    private let settings: [String: Setting]

    @objc public init(source: [String: Any], behaviour: OverrideBehaviour) {
        self.behaviour = behaviour
        var settings: [String: Setting] = [:]
        for (key, value) in source {
            settings[key] = Setting.fromAnyValue(value: value)
        }
        self.settings = settings
    }

    public func getOverrides() -> [String: Setting] {
        settings
    }
}
