# Steps to deploy
## Preparation
1. Make sure everything is ready for pod publish.
   ```bash
   pod lib lint
   ```
2. Run tests
3. Increase the version in the ConfigCat.podspec file (`spec.version`) and the `ConfigFetcher.swift` file (`private static let version: String`)
4. Commit & push.
## Publish
Use the **same version** for the git tag as in the podspec.
- Via git tag
    1. Create a new version tag.
       ```bash
       git tag [MAJOR].[MINOR].[PATCH]
       ```
       > Example: `git tag 2.5.5`
    2. Push the tag.
       ```bash
       git push origin --tags
       ```
- Via Github release 

  Create a new [Github release](https://github.com/configcat/swift-sdk/releases) with a new version tag and release notes.

## CocoaPods
Make sure the new version is available on [CocoaPods](https://cocoapods.org/pods/ConfigCat).
