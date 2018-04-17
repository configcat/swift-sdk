open class RefreshPolicy {
    public let cache: ConfigCache
    public let fetcher: ConfigFetcher
    
    var lastCachedConfiguration: String {
        return self.cache.inMemoryValue
    }
    
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        self.cache = cache
        self.fetcher = fetcher
    }
    
    open func getConfiguration() -> AsyncResult<String> {
        assert(false, "Method must be overidden!")
    }
    
    public final func refresh() -> Async {
        return self.fetcher.getConfigurationJson().accept { response in
            if response.isFetched() {
                self.cache.set(value: response.body)
            }
        }
    }
}
