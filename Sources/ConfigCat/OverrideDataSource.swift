import Foundation

public class OverrideDataSource : NSObject {
    let behaviour: OverrideBehaviour

    public required init(behaviour: OverrideBehaviour) {
        self.behaviour = behaviour
    }

    @objc public func getOverrides() -> [String: Any] { return [:] }
}
