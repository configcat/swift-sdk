# ConfigCat Swift SDK
ConfigCat is a cloud based configuration as a service. It integrates with your apps, backends, websites, 
and other programs, so you can configure them through [this](https://configcat.com) website even after they are deployed.

[![Build Status](https://travis-ci.org/configcat/swift-sdk.svg?branch=master)](https://travis-ci.org/configcat/swift-sdk)
[![CocoaPods](https://img.shields.io/cocoapods/v/ConfigCat.svg)](https://img.shields.io/cocoapods/v/ConfigCat.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Supported Platforms](https://img.shields.io/cocoapods/p/ConfigCat.svg?style=flat)](https://configcat.com/Docs#client-libs-ios)

## Getting started

**1. Add the package to your project**

**CocoaPods:**

Add the following to your `Podfile`:
```ruby
target '<YOUR TARGET>' do
pod 'ConfigCat'
end
```
Then, run the following command to install your dependencies:
```bash
pod install
```

**Carthage:**

Add the following to your `Cartfile`:
```
github "configcat/swift-sdk"
```
Then, run the `carthage update` command and then follow the [Carthage integration steps](https://github.com/Carthage/Carthage#getting-started) to link the framework with your project.

**2. Get your Api Key from [ConfigCat.com](https://configcat.com) portal**
![YourConnectionUrl](https://raw.githubusercontent.com/ConfigCat/java-sdk/master/media/readme01.png  "ApiKey")

**3. Import the ConfigCat module**
```swift
import ConfigCat
```

**4. Create a ConfigCatClient instance**
```swift
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>")
```
**5. Get your config value**
```swift
let isMyAwesomeFeatureEnabled = client.getValue(for: "key-of-my-awesome-feature", defaultValue: false)
if(isMyAwesomeFeatureEnabled) {
    //show your awesome feature to the world!
}
```
Or use the async APIs:
```swift
client.getValueAsync(for: "key-of-my-awesome-feature", defaultValue: false, completion: { isMyAwesomeFeatureEnabled in
        if(isMyAwesomeFeatureEnabled) {
            //show your awesome feature to the world!
        }
    })
```

## Configuration
### Refresh policies
The internal caching control and the communication between the client and ConfigCat are managed through a refresh policy. There are 3 predefined implementations built in the library.
#### 1. Auto polling policy (default)
This policy fetches the latest configuration and updates the cache repeatedly. 

You have the option to configure the polling interval and an `onConfigChanged` closure that will be notified when a new configuration is fetched. The policy calls the given method only, when the new configuration is differs from the cached one.
```swift
let factory = { (cache: ConfigCache, fetcher: ConfigFetcher) -> RefreshPolicy in
    AutoPollingPolicy(cache: cache,
                      fetcher: fetcher,
                      autoPollIntervalInSeconds: 30,
                      onConfigChanged: { (config, parser) in
                          let isMyAwesomeFeatureEnabled: String = try! parser.parseValue(for: "key-of-my-awesome-feature", json: configString)
                          if(isMyAwesomeFeatureEnabled) {
                              //show your awesome feature to the world!
                          }
                      })
}
        
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", policyFactory: factory)
```

#### 2. Expiring cache policy
This policy uses an expiring cache to maintain the internally stored configuration. 
##### Cache refresh interval 
You can define the refresh rate of the cache in seconds, 
after the initial cached value is set this value will be used to determine how much time must pass before initiating a new configuration fetch request through the `ConfigFetcher`.
##### Async / Sync refresh
You can define how do you want to handle the expiration of the cached configuration. If you choose asynchronous refresh then 
when a request is being made on the cache while it's expired, the previous value will be returned immediately 
until the fetching of the new configuration is completed.
```swift
let factory = { (cache: ConfigCache, fetcher: ConfigFetcher) -> RefreshPolicy in
    ExpiringCachePolicy(cache: cache,
                        fetcher: fetcher,
                        cacheRefreshIntervalInSeconds: 30,
                        useAsyncRefresh = true)
}
        
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", policyFactory: factory)
```

#### 3. Manual polling policy
With this policy every new configuration request on the ConfigCatClient will trigger a new fetch over HTTP.
```swift
let factory = { (cache: ConfigCache, fetcher: ConfigFetcher) -> RefreshPolicy in
    ManualPollingPolicy(cache, fetcher))
}
        
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", policyFactory: factory)
```

#### Custom Policy
You can also implement your custom refresh policy by extending the `RefreshPolicy` open class.
```swift
public class MyCustomPolicy : RefreshPolicy {
    public required init(cache: ConfigCache, fetcher: ConfigFetcher) {
        super.init(cache: cache, fetcher: fetcher)
    }
    
    public override func getConfiguration() -> AsyncResult<String> {
        // this method will be called when the configuration is requested from the ConfigCat client.
        // you can access the config fetcher through the super.fetcher and the internal cache via super.cache
    }
}
```
> The `AsyncResult` is an internal type used to signal back to the caller about the completion of a given task like [Futures](https://en.wikipedia.org/wiki/Futures_and_promises).

Then you can simply inject your custom policy implementation into the ConfigCat client:
```swift
let factory = { (cache: ConfigCache, fetcher: ConfigFetcher) -> RefreshPolicy in
    MyCustomPolicy(cache, fetcher))
}
        
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", policyFactory: factory)
```

### Custom Cache
You have the option to inject your custom cache implementation into the client. All you have to do is to inherit from the `ConfigCache` open class:
```swift
public class MyCustomCache : ConfigCache {
    open override func read() throws -> String {
        // here you have to return with the cached value
        // you can access the latest cached value in case 
        // of a failure like: super.inMemoryValue
    }
    
    open override func write(value: String) throws {
        // here you have to store the new value in the cache
    }
}
```
Then use your custom cache implementation:
```swift      
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", configCache: MyCustomCache())
```

### Maximum wait time for synchronous calls
You have the option to set a timeout value for the synchronous methods of the library (`getConfigurationJsonString()`, `getConfiguration()`, `getValue()` etc.) which means
when a sync call takes longer than the timeout value, it'll return with the default.
```swift      
let client = ConfigCatClient(apiKey: "<PLACE-YOUR-API-KEY-HERE>", maxWaitTimeForSyncCallsInSeconds: 5)
```

### Force refresh
Any time you want to refresh the cached configuration with the latest one, you can call the `forceRefresh()` method of the library,
which will initiate a new fetch and will update the local cache.

## Samples
* [iOS](https://github.com/configcat/swift-sdk/tree/master/samples/ios)
