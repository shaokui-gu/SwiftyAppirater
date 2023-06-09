Pod::Spec.new do |s|
  s.name         = "SwiftyAppirater"
  s.version      = "0.0.5"
  s.summary      = "SwiftyAppirater use swift"
  s.homepage     = "https://github.com/shaokui-gu/Swiftyirater"
  s.license      = 'MIT'
  s.author       = { 'gushaokui' => 'gushaoakui@126.com' }
  s.source       = { :git => "https://github.com/shaokui-gu/Swiftyirater.git" }
  s.source_files = 'Sources/*.swift'
  s.swift_versions = ['5.2', '5.3', '5.4']
  s.dependency 'ReachabilitySwift'
  s.requires_arc = true
end
