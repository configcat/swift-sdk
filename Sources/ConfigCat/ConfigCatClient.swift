import Foundation
import os.log

extension ConfigCatClient {
    public typealias ConfigChangedHandler = () -> ()
}

/// Describes the location of your feature flag and setting data within the ConfigCat CDN.
@objc public enum DataGovernance : Int {
    /// Select this if your feature flags are published to all global CDN nodes.
    case global
    /// Select this if your feature flags are published to CDN nodes only in the EU.
    case euOnly
}

/// A client for handling configurations provided by ConfigCat.
public final class ConfigCatClient : NSObject, ConfigCatClientProtocol {
    private let log: Logger
    private let evaluator: RolloutEvaluator
    private let configService: ConfigService?
    private let sdkKey: String
    private let overrideDataSource: OverrideDataSource?
    private static var sdkKeys: Set<String> = []

    /**
     Initializes a new `ConfigCatClient`.
     
     - Parameter sdkKey: the SDK Key for to communicate with the ConfigCat services.
     - Parameter dataGovernance: default: Global. Set this parameter to be in sync with the Data Governance preference on the Dashboard:
     https://app.configcat.com/organization/data-governance
     - Parameter configCache: a cache implementation, see `ConfigCache`.
     - Parameter refreshMode: the polling mode, `autoPoll`, `lazyLoad` or `manualPoll`.
     - Parameter sessionConfiguration: the url session configuration.
     - Parameter baseUrl: use this if you want to use a proxy server between your application and ConfigCat.
     - Parameter flagOverrides: An OverrideDataSource implementation used to override feature flags & settings.
     - Parameter logLevel: default: warning. Internal log level.
     - Returns: A new `ConfigCatClient`.
     */
    @objc public convenience init(sdkKey: String,
                dataGovernance: DataGovernance = DataGovernance.global,
                configCache: ConfigCache? = nil,
                refreshMode: PollingMode? = nil,
                sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                baseUrl: String = "",
                flagOverrides: OverrideDataSource? = nil,
                logLevel: LogLevel = .warning) {
        self.init(sdkKey: sdkKey, refreshMode: refreshMode, session: URLSession(configuration: sessionConfiguration),
                  configCache: configCache, baseUrl: baseUrl, dataGovernance: dataGovernance, flagOverrides: flagOverrides, logLevel: logLevel)
    }
    
    init(sdkKey: String,
                refreshMode: PollingMode?,
                session: URLSession?,
                configCache: ConfigCache? = nil,
                baseUrl: String = "",
                dataGovernance: DataGovernance = DataGovernance.global,
                flagOverrides: OverrideDataSource? = nil,
                logLevel: LogLevel = .warning) {
        if sdkKey.isEmpty {
            assert(false, "projectSecret cannot be empty")
        }

        log = Logger(level: logLevel)
        if (!ConfigCatClient.sdkKeys.insert(sdkKey).inserted) {
            log.warning(message: """
                                      A ConfigCat Client is already initialized with sdkKey %@.
                                      We strongly recommend you to use the ConfigCat Client as a Singleton object in your application.
                                      """, sdkKey)
        }
        self.sdkKey = sdkKey
        overrideDataSource = flagOverrides
        evaluator = RolloutEvaluator(logger: log)

        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            // configService is not needed in localOnly mode
            configService = nil
        } else {
            let mode = refreshMode ?? PollingModes.autoPoll()
            let fetcher = ConfigFetcher(session: session ?? URLSession(configuration: URLSessionConfiguration.default),
                                        logger: log,
                                        sdkKey: sdkKey,
                                        mode: mode.identifier,
                                        dataGovernance: dataGovernance,
                                        baseUrl: baseUrl)

            configService = ConfigService(log: log, fetcher: fetcher, cache: configCache, pollingMode: mode, sdkKey: sdkKey)
        }
    }

    deinit {
        ConfigCatClient.sdkKeys.remove(sdkKey)
    }

    // MARK: ConfigCatClientProtocol

    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil, completion: @escaping (Value) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        getSettings { settings in
            completion(self.getValueFromSettings(settings: settings, key: key, defaultValue: defaultValue, user: user))
        }
    }

    @objc public func getAllKeys(completion: @escaping ([String]) -> ()) {
        getSettings { settings in
            completion([String](settings.keys))
        }
    }

    @objc public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil, completion: @escaping (String?) -> ()) {
        if key.isEmpty {
            assert(false, "key cannot be empty")
        }
        getSettings { settings in
            completion(self.getVariationIdFromSettings(settings: settings, key: key, defaultVariationId: defaultVariationId, user: user))
        }
    }

    @objc public func getAllVariationIds(user: ConfigCatUser? = nil, completion: @escaping ([String]) -> ()) {
        getSettings { settings in
            completion(self.getAllVariationIdsFromSettings(settings: settings, user: user))
        }
    }

    @objc public func getKeyAndValue(for variationId: String, completion: @escaping (KeyValue?) -> ()) {
        getSettings { settings in
            completion(self.getKeyAndValueFromSettings(settings: settings, variationId: variationId))
        }
    }

    @objc public func getAllValues(user: ConfigCatUser? = nil, completion: @escaping ([String: Any]) -> ()) {
        getSettings { settings in
            completion(self.getAllValuesFromSettings(settings: settings, user: user))
        }
    }

    @objc public func refresh(completion: @escaping () -> ()) {
        if let configService = configService {
            configService.refresh(completion: completion)
        } else {
            log.warning(message: "The ConfigCat SDK is in local-only mode. Calling .refresh() has no effect.")
            completion()
        }
    }

    func getSettings(completion: @escaping ([String: Any]) -> Void) {
        if let overrideDataSource = overrideDataSource, overrideDataSource.behaviour == .localOnly {
            completion(overrideDataSource.getOverrides())
            return
        }
        guard let configService = configService else {
            completion([:])
            return
        }
        if let overrideDataSource = overrideDataSource {
            if overrideDataSource.behaviour == .localOverRemote {
                configService.settings { settings in
                    completion(settings.merging(overrideDataSource.getOverrides()) { (_, new) in new })
                }
                return
            }
            if overrideDataSource.behaviour == .remoteOverLocal {
                configService.settings { settings in
                    completion(settings.merging(overrideDataSource.getOverrides()) { (current, _) in current })
                }
                return
            }
        }
        configService.settings { settings in completion(settings) }
    }

    func getValueFromSettings<Value>(settings: [String: Any], key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
        if Value.self != String.self &&
            Value.self != String?.self &&
            Value.self != Int.self &&
            Value.self != Int?.self &&
            Value.self != Double.self &&
            Value.self != Double?.self &&
            Value.self != Bool.self &&
            Value.self != Bool?.self &&
            Value.self != Any.self &&
            Value.self != Any?.self {
            log.error(message: "Only String, Integer, Double, Bool or Any types are supported.")
            return defaultValue
        }
        if settings.isEmpty {
            log.error(message: "Config is not present. Returning defaultValue: [%@].", "\(defaultValue)");
            return defaultValue
        }

        let (value, _, evaluateLog): (Value?, String?, String?) = evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: "%@", evaluateLog)
        }
        if let value = value {
            return value
        }

        log.error(message: """
                                Evaluating the value for the key '%@' failed.
                                Returning defaultValue: [%@].
                                Here are the available keys: %@
                                """, key, "\(defaultValue)", [String](settings.keys))

        return defaultValue
    }

    func getVariationIdFromSettings(settings: [String: Any], key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let (_, variationId, evaluateLog): (Any?, String?, String?) = evaluator.evaluate(json: settings[key], key: key, user: user)
        if let evaluateLog = evaluateLog {
            log.info(message: "%@", evaluateLog)
        }
        if let variationId = variationId {
            return variationId
        }

        log.error(message: """
                                Evaluating the variation id for the key '%@' failed.
                                Returning defaultVariationId: %@
                                Here are the available keys: %@
                                """, key, defaultVariationId ?? "nil", [String](settings.keys))

        return defaultVariationId
    }

    func getAllVariationIdsFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String] {
        var variationIds = [String]()
        for key in settings.keys {
            let (_, variationId, evaluateLog): (Any?, String?, String?) = evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                log.info(message: "%@", evaluateLog)
            }
            if let variationId = variationId {
                variationIds.append(variationId)
            } else {
                log.error(message: "Evaluating the variation id for the key '%@' failed.", key)
            }
        }
        return variationIds
    }

    func getAllValuesFromSettings(settings: [String: Any], user: ConfigCatUser? = nil) -> [String: Any] {
        var allValues = [String: Any]()
        for key in settings.keys {
            let (value, _, evaluateLog): (Any?, String?, String?) = evaluator.evaluate(json: settings[key], key: key, user: user)
            if let evaluateLog = evaluateLog {
                log.info(message: "%@", evaluateLog)
            }
            if let value = value {
                allValues[key] = value
            } else {
                log.error(message: "Evaluating the value for the key '%@' failed.", key)
            }
        }
        return allValues
    }

    func getKeyAndValueFromSettings(settings: [String: Any], variationId: String) -> KeyValue? {
        for (key, json) in settings {
            if let json = json as? [String: Any], let value = json[Config.value] {
                if variationId == json[Config.variationId] as? String {
                    return KeyValue(key: key, value: value)
                }

                let rolloutRules = json[Config.rolloutRules] as? [[String: Any]] ?? []
                for rule in rolloutRules {
                    if variationId == rule[Config.variationId] as? String, let value = rule[Config.value]  {
                        return KeyValue(key: key, value: value)
                    }
                }

                let rolloutPercentageItems = json[Config.rolloutPercentageItems] as? [[String: Any]] ?? []
                for rule in rolloutPercentageItems {
                    if variationId == rule[Config.variationId] as? String, let value = rule[Config.value] {
                        return KeyValue(key: key, value: value)
                    }
                }
            }
        }

        log.error(message: "Could not find the setting for the given variationId: '%@'", variationId);
        return nil
    }
}

/// Objective-C interface extension.
/// Generic parameters are not available in Objective-C (getValue<Value>, getValueAsync<Value> cannot be marked @objc)
extension ConfigCatClient {
    @objc public func getStringValueAsync(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getIntValueAsync(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getDoubleValueAsync(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getBoolValueAsync(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
    @objc public func getAnyValueAsync(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }
}
