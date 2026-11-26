import Foundation

/// Custom data sources must support concurrent calls to `getOverrides()`.
open class OverrideDataSource: NSObject {
    let behaviour: OverrideBehaviour

    public init(behaviour: OverrideBehaviour) {
        self.behaviour = behaviour
    }

    @objc open func getOverrides() -> [String: Setting] {
        [:]
    }
}
