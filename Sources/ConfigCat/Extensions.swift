import Foundation

extension ConfigCatClient {
    @objc public func getStringValue(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (String) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }

    @objc public func getIntValue(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (Int) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }

    @objc public func getDoubleValue(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (Double) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }

    @objc public func getBoolValue(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (Bool) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }

    @objc public func getAnyValue(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (Any) -> ()) {
        return getValue(for: key, defaultValue: defaultValue, user: user, completion: completion)
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, *)
    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) async -> Value {
        await withCheckedContinuation { continuation in
            getValue(for: key, defaultValue: defaultValue) { value in
                continuation.resume(returning: value)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func getAllKeys() async -> [String] {
        await withCheckedContinuation { continuation in
            getAllKeys { keys in
                continuation.resume(returning: keys)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) async -> String? {
        await withCheckedContinuation { continuation in
            getVariationId(for: key, defaultVariationId: defaultVariationId) { variationId in
                continuation.resume(returning: variationId)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func getAllVariationIds(user: ConfigCatUser? = nil) async -> [String] {
        await withCheckedContinuation { continuation in
            getAllVariationIds { variationIds in
                continuation.resume(returning: variationIds)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func getKeyAndValue(for variationId: String) async -> KeyValue? {
        await withCheckedContinuation { continuation in
            getKeyAndValue(for: variationId) { value in
                continuation.resume(returning: value)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func getAllValues(user: ConfigCatUser? = nil) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            getAllValues(user: user) { values in
                continuation.resume(returning: values)
            }
        }
    }

    @available(macOS 10.15, iOS 13, *)
    public func refresh() async {
        await withCheckedContinuation { continuation in
            refresh {
                continuation.resume()
            }
        }
    }
    #endif

    // Synchronous extensions

    public func getValueSync<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Value?
        getValue(for: key, defaultValue: defaultValue) { value in
            result = value
            semaphore.signal()
        }
        semaphore.wait()
        return result ?? defaultValue
    }

    @objc public func getAllKeysSync() -> [String] {
        let semaphore = DispatchSemaphore(value: 0)
        var result = [String]()
        getAllKeys { keys in
            result = keys
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @objc public func getVariationIdSync(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        getVariationId(for: key, defaultVariationId: defaultVariationId) { variationId in
            result = variationId
            semaphore.signal()
        }
        semaphore.wait()
        return result ?? defaultVariationId
    }

    @objc public func getAllVariationIdsSync(user: ConfigCatUser? = nil) -> [String] {
        let semaphore = DispatchSemaphore(value: 0)
        var result = [String]()
        getAllVariationIds(user: user) { variationIds in
            result = variationIds
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @objc public func getKeyAndValueSync(for variationId: String) -> KeyValue? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: KeyValue?
        getKeyAndValue(for: variationId) { value in
            result = value
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @objc public func getAllValuesSync(user: ConfigCatUser? = nil) -> [String: Any] {
        let semaphore = DispatchSemaphore(value: 0)
        var result = [String: Any]()
        getAllValues(user: user) { values in
            result = values
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @objc public func refreshSync() {
        let semaphore = DispatchSemaphore(value: 0)
        refresh {
            semaphore.signal()
        }
        semaphore.wait()
    }

    @objc public func getStringValueSync(for key: String, defaultValue: String, user: ConfigCatUser?) -> String {
        getValueSync(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getIntValueSync(for key: String, defaultValue: Int, user: ConfigCatUser?) -> Int {
        getValueSync(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getDoubleValueSync(for key: String, defaultValue: Double, user: ConfigCatUser?) -> Double {
        getValueSync(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getBoolValueSync(for key: String, defaultValue: Bool, user: ConfigCatUser?) -> Bool {
        getValueSync(for: key, defaultValue: defaultValue, user: user)
    }

    @objc public func getAnyValueSync(for key: String, defaultValue: Any, user: ConfigCatUser?) -> Any {
        getValueSync(for: key, defaultValue: defaultValue, user: user)
    }
}

