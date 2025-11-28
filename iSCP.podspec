Pod::Spec.new do |spec|
spec.name         = "iSCP"
  spec.version      = "1.2.0"
  spec.summary      = "iSCP 2.0 Client Library for Swift"
  spec.homepage     = "https://github.com/aptpod/iscp-swift"

  spec.license      = { :type => "Apache License, Version 2.0" }
  spec.author       = { "aptpod" => "ueno@aptpod.co.jp" }

  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "10.15"
  spec.source       = { :git => "https://github.com/aptpod/iscp-swift.git", :tag => "v#{spec.version}" }

  spec.vendored_frameworks = "iSCP.xcframework"
  spec.requires_arc = true
  spec.swift_versions = "5.0"
  spec.static_framework = false

end
