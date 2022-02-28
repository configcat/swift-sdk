# ConfigCat SDK for Swift
https://configcat.com

ConfigCat SDK for Swift provides easy integration for your application to ConfigCat.

ConfigCat is a feature flag and configuration management service that lets you separate releases from deployments. You can turn your features ON/OFF using <a href="https://app.configcat.com" target="_blank">ConfigCat Dashboard</a> even after they are deployed. ConfigCat lets you target specific groups of users based on region, email or any other custom user attribute.

ConfigCat is a <a href="https://configcat.com" target="_blank">hosted feature flag service</a>. Manage feature toggles across frontend, backend, mobile, desktop apps. <a href="https://configcat.com" target="_blank">Alternative to LaunchDarkly</a>. Management app + feature flag SDKs.

[![Build Status](https://github.com/configcat/swift-sdk/actions/workflows/swift-ci.yml/badge.svg?branch=master)](https://github.com/configcat/swift-sdk/actions/workflows/swift-ci.yml)
[![Coverage Status](https://img.shields.io/codecov/c/github/ConfigCat/swift-sdk.svg)](https://codecov.io/gh/ConfigCat/swift-sdk)
[![CocoaPods](https://img.shields.io/cocoapods/v/ConfigCat.svg)](https://cocoapods.org/pods/ConfigCat)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Supported Platforms](https://img.shields.io/cocoapods/p/ConfigCat.svg?style=flat)](https://configcat.com/docs/sdk-reference/ios)
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

**Swift Package Manager:**

You can add ConfigCat to an Xcode project by adding it as a package dependency.

> https://github.com/configcat/swift-sdk

If you want to use ConfigCat in a [SwiftPM](https://swift.org/package-manager/) project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

``` swift
dependencies: [
  .package(url: "https://github.com/configcat/swift-sdk", from: "8.0.0")
]
```

### 2. Go to the <a href="https://app.configcat.com/sdkkey" target="_blank">ConfigCat Dashboard</a> to get your *SDK Key*:
![SDK-KEY](https://raw.githubusercontent.com/ConfigCat/swift-sdk/master/media/readme02-3.png  "SDK-KEY")

### 3. Import the *ConfigCat* module to your application
```swift
import ConfigCat
```

### 4. Create a *ConfigCat* client instance
```swift
let client = ConfigCatClient(sdkKey: "#YOUR-SDK-KEY#")
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

Read more about [Targeting here](https://configcat.com/docs/advanced/targeting/).

```swift
let user = ConfigCatUser(identifier: "#USER-IDENTIFIER#")
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
The ConfigCat SDK supports 3 different polling mechanisms to acquire the setting values from ConfigCat. After latest setting values are downloaded, they are stored in the internal cache then all requests are served from there. Read more about Polling Modes and how to use them at [ConfigCat Docs](https://configcat.com/docs/sdk-reference/ios/).

## Need help?
https://configcat.com/support

## Contributing
Contributions are welcome. For more info please read the [Contribution Guideline](CONTRIBUTING.md).

## About ConfigCat
- [Official ConfigCat SDKs for other platforms](https://github.com/configcat)
- [Documentation](https://configcat.com/docs)
- [Blog](https://configcat.com/blog)
