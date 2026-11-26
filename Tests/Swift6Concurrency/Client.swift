import ConfigCat

func checkSendable<T: Sendable>(_: T.Type) {}

@MainActor
func checkAsyncResults(client: ConfigCatClient, user: ConfigCatUser) async {
    checkSendable(ScalarValue.self)
    checkSendable(TypedEvaluationDetails<ScalarValue>.self)
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
