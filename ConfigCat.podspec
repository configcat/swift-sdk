Pod::Spec.new do |spec|

  spec.name          = "ConfigCat"
  spec.version       = "2.2.0"
  spec.summary       = "ConfigCat Swift SDK"
  spec.swift_version = "4.2"

  spec.description  = "ConfigCat is a feature flag, feature toggle, and configuration management service. That lets you launch new features and change your software configuration remotely without actually (re)deploying code. ConfigCat even helps you do controlled roll-outs like canary releases and blue-green deployments."
  spec.homepage     = "https://github.com/configcat/swift-sdk"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "ConfigCat" => "developer@configcat.com" }

  spec.ios.deployment_target     = "10.0"
  spec.watchos.deployment_target = "3.0"
  spec.tvos.deployment_target    = "10.0"
  spec.osx.deployment_target     = '10.12'

  spec.source            = { :git => "https://github.com/configcat/swift-sdk.git", :tag => spec.version }
  spec.source_files      = "Sources/*.swift"
  spec.requires_arc      = true
  spec.module_name       = "ConfigCat"
  spec.documentation_url = "https://docs.configcat.com/docs/sdk-reference/ios"

end
