# ConfigCat SDK for Swift

ConfigCat SDK for Swift provides easy integration between ConfigCat service and applications using Swift.

ConfigCat is a feature flag, feature toggle, and configuration management service. That lets you launch new features and change your software configuration remotely without actually (re)deploying code. ConfigCat even helps you do controlled roll-outs like canary releases and blue-green deployments.
https://configcat.com  

[![Build Status](https://travis-ci.org/configcat/swift-sdk.svg?branch=master)](https://travis-ci.org/configcat/swift-sdk)
[![Coverage Status](https://img.shields.io/codecov/c/github/ConfigCat/swift-sdk.svg)](https://codecov.io/gh/ConfigCat/swift-sdk)
[![CocoaPods](https://img.shields.io/cocoapods/v/ConfigCat.svg)](https://cocoapods.org/pods/ConfigCat)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Supported Platforms](https://img.shields.io/cocoapods/p/ConfigCat.svg?style=flat)](https://docs.configcat.com/docs/sdk-reference/ios)
![License](https://img.shields.io/github/license/configcat/swift-sdk.svg)

## Getting started

### 1. Install the package

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

### 2. <a href="https://configcat.com/Account/Login" target="_blank">Log in to ConfigCat Management Console</a> and go to your *Project* to get your *API Key*
![API-KEY](https://raw.githubusercontent.com/ConfigCat/swift-sdk/master/media/readme01.png  "API-KEY")

### 3. Import the *ConfigCat* module to your application
```swift
import ConfigCat
```

### 4. Create a *ConfigCat* client instance
```swift
let client = ConfigCatClient(apiKey: "#YOUR-API-KEY#")
```

### 5. Get your setting value
```swift
let isMyAwesomeFeatureEnabled = client.getValue(for: "isMyAwesomeFeatureEnabled", defaultValue: false)
if(isMyAwesomeFeatureEnabled) {
    doTheNewThing()
} else {
    doTheOldThing()
}
```
Or use the async APIs:
```swift
client.getValueAsync(for: "isMyAwesomeFeatureEnabled", defaultValue: false, completion: { isMyAwesomeFeatureEnabled in
        if(isMyAwesomeFeatureEnabled) {
            doTheNewThing()
        } else {
            doTheOldThing()
        }
    })
```

## Getting user specific setting values with Targeting
Using this feature, you will be able to get different setting values for different users in your application by passing a `User Object` to the `getValue()` function.

Read more about [Targeting here](https://docs.configcat.com/docs/advanced/targeting/).

```swift
let user = User(identifier: "#USER-IDENTIFIER#")
let isMyAwesomeFeatureEnabled = client.getValue(for: "isMyAwesomeFeatureEnabled", user: user, defaultValue: false)
if(isMyAwesomeFeatureEnabled) {
    doTheNewThing()
} else {
    doTheOldThing()
}
```

## Sample/Demo app
  [Sample iOS app](https://github.com/configcat/swift-sdk/tree/master/samples/ios)

## Polling Modes
The ConfigCat SDK supports 3 different polling mechanisms to acquire the setting values from ConfigCat. After latest setting values are downloaded, they are stored in the internal cache then all requests are served from there. Read more about Polling Modes and how to use them at [ConfigCat Docs](https://docs.configcat.com/docs/sdk-reference/ios/).

## Support
If you need help how to use this SDK feel free to to contact the ConfigCat Staff on https://configcat.com. We're happy to help.

## Contributing
Contributions are welcome.

## License
[MIT](https://raw.githubusercontent.com/ConfigCat/swift-sdk/master/LICENSE)
