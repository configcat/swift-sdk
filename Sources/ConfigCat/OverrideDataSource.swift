import Foundation

/// Custom data sources must support concurrent calls to `getOverrides()`.
@objc public protocol OverrideDataSource: Sendable {
    var behaviour: OverrideBehaviour { get }

    @objc func getOverrides() -> [String: Setting]
}
