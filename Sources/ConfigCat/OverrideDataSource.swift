import Foundation

open class OverrideDataSource: NSObject {
    let behaviour: OverrideBehaviour

    public init(behaviour: OverrideBehaviour) {
        self.behaviour = behaviour
    }

    @objc public func getOverrides() -> [String: Setting] {
        [:]
    }
}
