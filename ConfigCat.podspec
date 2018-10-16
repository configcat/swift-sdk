Pod::Spec.new do |spec|

  spec.name          = "ConfigCat"
  spec.version       = "2.1.1"
  spec.summary       = "ConfigCat Swift SDK"
  spec.swift_version = "4.2"

  spec.description  = "ConfigCat is a cloud based configuration as a service. It integrates with your apps, backends, websites, and other programs, so you can configure them through this website even after they are deployed."
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
