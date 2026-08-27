Pod::Spec.new do |s|
  s.name             = 'bull_tor'
  s.version          = '0.0.1'
  s.summary          = 'Bull Mobile Tor lifecycle and platform integration.'
  s.description      = <<-DESC
Bull Mobile Tor lifecycle and platform integration.
                       DESC
  s.homepage         = 'https://github.com/SatoshiPortal/bullbitcoin-mobile'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Bull Bitcoin' => 'support@bullbitcoin.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
end
