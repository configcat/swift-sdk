import ConfigCat

func checkSendable<T: Sendable>(_: T.Type) {}

@MainActor
func checkAsyncResults(client: ConfigCatClient, user: ConfigCatUser) async {
    checkSendable(FlagValue.self)
    checkSendable(TypedEvaluationDetails<FlagValue>.self)
    checkSendable(RefreshResult.self)
    checkSendable(ClientCacheState.self)
    checkSendable(ConfigCatClientSnapshot.self)

    let snapshot = client.snapshot()
    let snapshotValue = await Task.detached { @Sendable in
        snapshot.getValue(for: "flag", defaultValue: false, user: user)
    }.value
    let values = await Task.detached { await client.getAllValues(user: user) }.value
    let details = await Task.detached { await client.getAllValueDetails(user: user) }.value
    let value = await Task.detached { await client.getValue(for: "flag", defaultValue: false, user: user) }.value
    let valueDetails = await Task.detached { await client.getValueDetails(for: "flag", defaultValue: Optional<String>.none, user: user) }.value
    let refresh = await Task.detached { await client.forceRefresh() }.value
    let state = await Task.detached { await client.waitForReady() }.value
    _ = (snapshotValue, values, details, value, valueDetails, refresh, state)
}

@MainActor
func checkProtocolResults(client: any ConfigCatClientProtocol, user: ConfigCatUser) async {
    let values = await Task.detached { await client.getAllValues(user: user) }.value
    let details = await Task.detached { await client.getAllValueDetails(user: user) }.value
    let value = await Task.detached { await client.getValue(for: "flag", defaultValue: false, user: user) }.value
    let valueDetails = await Task.detached { await client.getValueDetails(for: "flag", defaultValue: Optional<String>.none, user: user) }.value
    _ = (values, details, value, valueDetails)
}

@MainActor
final class CallbackOwner {
    var count = 0

    func subscribe(client: ConfigCatClient, protocolClient: any ConfigCatClientProtocol) {
        client.hooks.addOnReady { [weak self] _ in
            Task { @MainActor in self?.count += 1 }
        }
        client.hooks.addOnFlagEvaluated { [weak self] _ in
            Task { @MainActor in self?.count += 1 }
        }
        client.hooks.addOnError { [weak self] _ in
            Task { @MainActor in self?.count += 1 }
        }
        client.hooks.addOnConfigChanged { config, _ in
            Task.detached { @Sendable in
                _ = config.settings
            }
        }
        client.getValue(for: "flag", defaultValue: false) { [weak self] _ in
            Task { @MainActor in self?.count += 1 }
        }
        protocolClient.getAllKeys { [weak self] _ in
            Task { @MainActor in self?.count += 1 }
        }

        #if NEGATIVE_READY
        client.hooks.addOnReady { _ in self.count += 1 }
        #elseif NEGATIVE_FLAG_EVALUATED
        client.hooks.addOnFlagEvaluated { _ in self.count += 1 }
        #elseif NEGATIVE_CONFIG_CHANGED
        client.hooks.addOnConfigChanged { _, _ in self.count += 1 }
        #elseif NEGATIVE_ERROR
        client.hooks.addOnError { _ in self.count += 1 }
        #endif

        #if NEGATIVE_CALLBACK
        #if TARGET_PROTOCOL
        let callbackClient = protocolClient
        #else
        let callbackClient = client
        #endif

        #if NEGATIVE_GET_VALUE
        callbackClient.getValue(for: "flag", defaultValue: false, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_VALUE_DETAILS
        callbackClient.getValueDetails(for: "flag", defaultValue: false, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_ALL_VALUES
        callbackClient.getAllValues(user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_ALL_VALUE_DETAILS
        callbackClient.getAllValueDetails(user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_ALL_VALUES_OBJC
        callbackClient.getAllValuesObjC(user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_ALL_VALUE_DETAILS_OBJC
        callbackClient.getAllValueDetailsObjC(user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_ALL_KEYS
        callbackClient.getAllKeys { _ in self.count += 1 }
        #elseif NEGATIVE_GET_KEY_AND_VALUE
        callbackClient.getKeyAndValue(for: "variation") { _ in self.count += 1 }
        #elseif NEGATIVE_FORCE_REFRESH
        callbackClient.forceRefresh { _ in self.count += 1 }
        #elseif NEGATIVE_GET_STRING_VALUE
        callbackClient.getStringValue(for: "flag", defaultValue: "", user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_BOOL_VALUE
        callbackClient.getBoolValue(for: "flag", defaultValue: false, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_INT_VALUE
        callbackClient.getIntValue(for: "flag", defaultValue: 0, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_DOUBLE_VALUE
        callbackClient.getDoubleValue(for: "flag", defaultValue: 0, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_STRING_VALUE_DETAILS
        callbackClient.getStringValueDetails(for: "flag", defaultValue: "", user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_BOOL_VALUE_DETAILS
        callbackClient.getBoolValueDetails(for: "flag", defaultValue: false, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_INT_VALUE_DETAILS
        callbackClient.getIntValueDetails(for: "flag", defaultValue: 0, user: nil) { _ in self.count += 1 }
        #elseif NEGATIVE_GET_DOUBLE_VALUE_DETAILS
        callbackClient.getDoubleValueDetails(for: "flag", defaultValue: 0, user: nil) { _ in self.count += 1 }
        #endif
        #endif
    }
}
