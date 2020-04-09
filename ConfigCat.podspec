Pod::Spec.new do |spec|

  spec.name          = "ConfigCat"
  spec.version       = "5.0.1"
  spec.summary       = "ConfigCat Swift SDK"
  spec.swift_version = "4.2"

  spec.description  = "Feature Flags created by developers for developers with ❤️. ConfigCat lets you manage feature flags across frontend, backend, mobile, and desktop apps without (re)deploying code. % rollouts, user targeting, segmentation. Feature toggle SDKs for all main languages. Alternative to LaunchDarkly. Host yourself, or use the hosted management app at https://configcat.com."
  spec.homepage     = "https://github.com/configcat/swift-sdk"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "ConfigCat" => "developer@configcat.com" }

  spec.ios.deployment_target     = "10.0"
  spec.watchos.deployment_target = "3.0"
  spec.tvos.deployment_target    = "10.0"
  spec.osx.deployment_target     = '10.12'

  spec.source            = { :git => "https://github.com/configcat/swift-sdk.git", :tag => spec.version }
  spec.source_files      = "Sources/*.swift", "Version/*.swift"
  spec.requires_arc      = true
  spec.module_name       = "ConfigCat"
  spec.documentation_url = "https://configcat.com/docs/sdk-reference/ios"

end