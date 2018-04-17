import Foundation

public final class ManualPollingPolicy : RefreshPolicy {    
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        fetcher.mode = "manual"
        super.init(cache: cache, fetcher: fetcher)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        return super.fetcher.getConfigurationJson()
            .apply(completion: { response in
                let cached = super.cache.get()
                let config = response.body
                if response.isFetched() && config != cached {
                    super.cache.set(value: config)
                }
                
                return response.isFetched() ? config : cached
            })
    }
}
