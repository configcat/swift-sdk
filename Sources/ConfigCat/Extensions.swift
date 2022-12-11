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

    @objc public func getAnyValueDetails(for key: String, defaultValue: Any, user: ConfigCatUser?, completion: @escaping (EvaluationDetails) -> ()) {
        return getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
            completion(EvaluationDetails(key: details.key,
                    value: details.value,
                    variationId: details.variationId,
                    fetchTime: details.fetchTime,
                    user: user,
                    isDefaultValue: details.isDefaultValue,
                    error: details.error,
                    matchedEvaluationRule: details.matchedEvaluationRule,
                    matchedEvaluationPercentageRule: details.matchedEvaluationPercentageRule))
        }
    }

    @objc public func getStringValueDetails(for key: String, defaultValue: String, user: ConfigCatUser?, completion: @escaping (StringEvaluationDetails) -> ()) {
        return getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
            completion(details.toStringDetails())
        }
    }

    @objc public func getBoolValueDetails(for key: String, defaultValue: Bool, user: ConfigCatUser?, completion: @escaping (BoolEvaluationDetails) -> ()) {
        return getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
            completion(details.toBoolDetails())
        }
    }

    @objc public func getIntValueDetails(for key: String, defaultValue: Int, user: ConfigCatUser?, completion: @escaping (IntEvaluationDetails) -> ()) {
        return getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
            completion(details.toIntDetails())
        }
    }

    @objc public func getDoubleValueDetails(for key: String, defaultValue: Double, user: ConfigCatUser?, completion: @escaping (DoubleEvaluationDetails) -> ()) {
        return getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
            completion(details.toDoubleDetails())
        }
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getValue<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) async -> Value {
        await withCheckedContinuation { continuation in
            getValue(for: key, defaultValue: defaultValue, user: user) { value in
                continuation.resume(returning: value)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getValueDetails<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) async -> TypedEvaluationDetails<Value> {
        await withCheckedContinuation { continuation in
            getValueDetails(for: key, defaultValue: defaultValue, user: user) { details in
                continuation.resume(returning: details)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getAllValueDetails(user: ConfigCatUser? = nil) async -> [EvaluationDetails] {
        await withCheckedContinuation { continuation in
            getAllValueDetails(user: user) { details in
                continuation.resume(returning: details)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getAllKeys() async -> [String] {
        await withCheckedContinuation { continuation in
            getAllKeys { keys in
                continuation.resume(returning: keys)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @available(*, deprecated, message: "This method is obsolete and will be removed in a future major version. Please use getValueDetails() instead.")
    public func getVariationId(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) async -> String? {
        await withCheckedContinuation { continuation in
            getVariationId(for: key, defaultVariationId: defaultVariationId, user: user) { variationId in
                continuation.resume(returning: variationId)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @available(*, deprecated, message: "This method is obsolete and will be removed in a future major version. Please use getAllValueDetails() instead.")
    public func getAllVariationIds(user: ConfigCatUser? = nil) async -> [String] {
        await withCheckedContinuation { continuation in
            getAllVariationIds(user: user) { variationIds in
                continuation.resume(returning: variationIds)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getKeyAndValue(for variationId: String) async -> KeyValue? {
        await withCheckedContinuation { continuation in
            getKeyAndValue(for: variationId) { value in
                continuation.resume(returning: value)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public func getAllValues(user: ConfigCatUser? = nil) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            getAllValues(user: user) { values in
                continuation.resume(returning: values)
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @available(*, deprecated, message: "Use `forceRefresh()` instead")
    public func refresh() async {
        await withCheckedContinuation { continuation in
            forceRefresh { _ in
                continuation.resume()
            }
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    @discardableResult
    public func forceRefresh() async -> RefreshResult {
        await withCheckedContinuation { continuation in
            forceRefresh { result in
                continuation.resume(returning: result)
            }
        }
    }
    #endif

    // Synchronous extensions

    public func getValueSync<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> Value {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Value?
        getValue(for: key, defaultValue: defaultValue, user: user) { value in
            result = value
            semaphore.signal()
        }
        semaphore.wait()
        return result ?? defaultValue
    }

    public func getValueDetailsSync<Value>(for key: String, defaultValue: Value, user: ConfigCatUser? = nil) -> TypedEvaluationDetails<Value> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: TypedEvaluationDetails<Value>?
        getValueDetails(for: key, defaultValue: defaultValue, user: user) { value in
            result = value
            semaphore.signal()
        }
        semaphore.wait()
        return result ?? TypedEvaluationDetails<Value>.fromError(key: key, value: defaultValue, error: String(format: "Could not get the evaluation details for '%@'.", key), user: user)
    }

    @objc public func getAllValueDetailsSync(user: ConfigCatUser? = nil) -> [EvaluationDetails] {
        let semaphore = DispatchSemaphore(value: 0)
        var result = [EvaluationDetails]()
        getAllValueDetails(user: user) { details in
            result = details
            semaphore.signal()
        }
        semaphore.wait()
        return result
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

    @available(*, deprecated, message: "This method is obsolete and will be removed in a future major version. Please use getValueDetailsSync() instead.")
    @objc public func getVariationIdSync(for key: String, defaultVariationId: String?, user: ConfigCatUser? = nil) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        getVariationId(for: key, defaultVariationId: defaultVariationId, user: user) { variationId in
            result = variationId
            semaphore.signal()
        }
        semaphore.wait()
        return result ?? defaultVariationId
    }

    @available(*, deprecated, message: "This method is obsolete and will be removed in a future major version. Please use getAllValueDetailsSync() instead.")
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

    @available(*, deprecated, message: "Use `forceRefreshSync()` instead")
    @objc public func refreshSync() {
        let semaphore = DispatchSemaphore(value: 0)
        forceRefresh { _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    @discardableResult
    @objc public func forceRefreshSync() -> RefreshResult {
        let semaphore = DispatchSemaphore(value: 0)
        var refreshResult: RefreshResult?
        forceRefresh { result in
            refreshResult = result
            semaphore.signal()
        }
        semaphore.wait()
        return refreshResult ?? RefreshResult(success: false)
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

    @objc public func getStringValueDetailsSync(for key: String, defaultValue: String, user: ConfigCatUser?) -> StringEvaluationDetails {
        getValueDetailsSync(for: key, defaultValue: defaultValue, user: user).toStringDetails()
    }

    @objc public func getIntValueDetailsSync(for key: String, defaultValue: Int, user: ConfigCatUser?) -> IntEvaluationDetails {
        getValueDetailsSync(for: key, defaultValue: defaultValue, user: user).toIntDetails()
    }

    @objc public func getDoubleValueDetailsSync(for key: String, defaultValue: Double, user: ConfigCatUser?) -> DoubleEvaluationDetails {
        getValueDetailsSync(for: key, defaultValue: defaultValue, user: user).toDoubleDetails()
    }

    @objc public func getBoolValueDetailsSync(for key: String, defaultValue: Bool, user: ConfigCatUser?) -> BoolEvaluationDetails {
        getValueDetailsSync(for: key, defaultValue: defaultValue, user: user).toBoolDetails()
    }
}

