# ConfigCat SDK for Swift

[![Build Status](https://github.com/configcat/swift-sdk/actions/workflows/swift-ci.yml/badge.svg?branch=master)](https://github.com/configcat/swift-sdk/actions/workflows/swift-ci.yml)
[![CocoaPods](https://img.shields.io/cocoapods/v/ConfigCat.svg)](https://cocoapods.org/pods/ConfigCat)
[![Supported Platforms](https://img.shields.io/cocoapods/p/ConfigCat.svg?style=flat)](https://configcat.com/docs/sdk-reference/ios)
[![Coverage Status](https://img.shields.io/sonar/coverage/configcat_swift-sdk?logo=SonarCloud&server=https%3A%2F%2Fsonarcloud.io)](https://sonarcloud.io/project/overview?id=configcat_swift-sdk)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=configcat_swift-sdk&metric=alert_status)](https://sonarcloud.io/dashboard?id=configcat_swift-sdk)

ConfigCat SDK for Swift provides easy integration for your application to [ConfigCat](https://configcat.com).

The following device platform versions are supported:

| Platform | Version    |
| -------- | ---------- |
| iOS      | >= 12.0    |
| watchOS  | >= 4.0     |
| tvOS     | >= 12.0    |
| macOS    | >= 10.13   |
| visionOS | >= 1.0     |

## Getting started

### 1. Install the package

- ### CocoaPods

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

- ### Swift Package Manager

  You can add ConfigCat to an Xcode project by adding it as a package dependency.

  > https://github.com/configcat/swift-sdk

  If you want to use ConfigCat in a [SwiftPM](https://swift.org/package-manager/) project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

  ``` swift
  dependencies: [
    .package(url: "https://github.com/configcat/swift-sdk", from: "11.0.2")
  ]
  ```

- ### Carthage

  Add the following to your `Cartfile`:
  ```
  github "configcat/swift-sdk"
  ```
  Then, run the `carthage update` command and then follow the [Carthage integration steps](https://github.com/Carthage/Carthage#getting-started) to link the framework with your project.

### 2. Go to the <a href="https://app.configcat.com/sdkkey" target="_blank">ConfigCat Dashboard</a> to get your *SDK Key*:
![SDK-KEY](https://raw.githubusercontent.com/ConfigCat/swift-sdk/master/media/readme02-3.png  "SDK-KEY")

### 3. Import the *ConfigCat* module to your application
```swift
import ConfigCat
```

### 4. Create a *ConfigCat* client instance
```swift
let client = ConfigCatClient.get(sdkKey: "#YOUR-SDK-KEY#")
```

### 5. Get your setting value
```swift
client.getValue(for: "isMyAwesomeFeatureEnabled", defaultValue: false) { isMyAwesomeFeatureEnabled in
    if isMyAwesomeFeatureEnabled {
        doTheNewThing()
    } else {
        doTheOldThing()
    }
}

// or with async/await
let isMyAwesomeFeatureEnabled = await client.getValue(for: "isMyAwesomeFeatureEnabled", defaultValue: false)
if isMyAwesomeFeatureEnabled {
    doTheNewThing()
} else {
    doTheOldThing()
}
```

### 6. Close the client on application exit
 ```swift
 client.close();
 ```

## Getting user specific setting values with Targeting
Using this feature, you will be able to get different setting values for different users in your application by passing a `User Object` to the `getValue()` function.

Read more about [Targeting here](https://configcat.com/docs/advanced/targeting/).

```swift
let user = ConfigCatUser(identifier: "#USER-IDENTIFIER#")
client.getValue(for: "isMyAwesomeFeatureEnabled", defaultValue: false, user: user) { isMyAwesomeFeatureEnabled in
    if isMyAwesomeFeatureEnabled {
        doTheNewThing()
    } else {
        doTheOldThing()
    }
}
```

## Sample/Demo app
  [Sample iOS app](https://github.com/configcat/swift-sdk/tree/master/samples/ios)

## Polling Modes
The ConfigCat SDK supports 3 different polling mechanisms to acquire the setting values from ConfigCat. After latest setting values are downloaded, they are stored in the internal cache then all requests are served from there. Read more about Polling Modes and how to use them at [ConfigCat Docs](https://configcat.com/docs/sdk-reference/ios/).

## Sensitive information handling

The frontend/mobile SDKs are running in your users' browsers/devices. The SDK is downloading a [config.json](https://configcat.com/docs/requests) file from ConfigCat's CDN servers. The URL path for this config.json file contains your SDK key, so the SDK key and the content of your config.json file (feature flag keys, feature flag values, targeting rules, % rules) can be visible to your users. 
This SDK key is read-only, it only allows downloading your config.json file, but nobody can make any changes with it in your ConfigCat account.

If you do not want to expose the SDK key or the content of the config.json file, we recommend using the SDK in your backend components only. You can always create a backend endpoint using the ConfigCat SDK that can evaluate feature flags for a specific user, and call that backend endpoint from your frontend/mobile applications.

Also, we recommend using [confidential targeting comparators](https://configcat.com/docs//advanced/targeting/#confidential-text-comparators) in the targeting rules of those feature flags that are used in the frontend/mobile SDKs.

## Need help?
https://configcat.com/support

## Contributing
Contributions are welcome. For more info please read the [Contribution Guideline](CONTRIBUTING.md).

## About ConfigCat
ConfigCat is a feature flag and configuration management service that lets you separate releases from deployments. You can turn your features ON/OFF using <a href="https://app.configcat.com" target="_blank">ConfigCat Dashboard</a> even after they are deployed. ConfigCat lets you target specific groups of users based on region, email or any other custom user attribute.

ConfigCat is a <a href="https://configcat.com" target="_blank">hosted feature flag service</a>. Manage feature toggles across frontend, backend, mobile, desktop apps. <a href="https://configcat.com" target="_blank">Alternative to LaunchDarkly</a>. Management app + feature flag SDKs.

- [Official ConfigCat SDKs for other platforms](https://github.com/configcat)
- [Documentation](https://configcat.com/docs)
- [Blog](https://configcat.com/blog)
