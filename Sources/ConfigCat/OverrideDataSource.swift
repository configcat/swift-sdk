import Foundation

public class OverrideDataSource: NSObject {
    let behaviour: OverrideBehaviour

    init(behaviour: OverrideBehaviour) {
        self.behaviour = behaviour
    }

    @objc public func getOverrides() -> [String: Any] {
        [:]
    }
}
