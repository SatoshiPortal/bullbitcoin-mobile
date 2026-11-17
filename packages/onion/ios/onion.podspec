#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint onion.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'onion'
  s.version          = '0.1.0'
  s.summary          = 'Embedded Tor client and loopback SOCKS5 proxy.'
  s.description      = <<-DESC
Embedded Tor client and loopback SOCKS5 proxy for Bull Bitcoin, built on Arti.
                       DESC
  s.homepage         = 'https://github.com/SatoshiPortal/bull_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Satoshi Portal' => 'https://bullbitcoin.com' }
  s.module_name      = 'onion'

  s.source           = { :path => '.' }
  s.source_files = 'onion/Sources/onion/**/*.{h,m,c}'
  s.public_header_files = 'onion/Sources/onion/include/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'IPtProxy', '5.6.0'
  s.platform = :ios, '15.0'

  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Verify IPtProxy binary',
    :script => <<-SCRIPT,
set -eu
case "$PLATFORM_NAME" in
  iphonesimulator*)
    iptproxy_binary="$PODS_ROOT/IPtProxy/IPtProxy.xcframework/ios-arm64_x86_64-simulator/IPtProxy.framework/IPtProxy"
    expected_sha256="a5ba4da9e234d9eb4dfc25a02b6c2aee9b8830125f6018487f29bb16223d9e88"
    ;;
  *)
    iptproxy_binary="$PODS_ROOT/IPtProxy/IPtProxy.xcframework/ios-arm64/IPtProxy.framework/IPtProxy"
    expected_sha256="c0d98505601e384e18d182512b8bd83c05960fa2921c4a29bd115f69796b8778"
    ;;
esac
actual_sha256="$(shasum -a 256 "$iptproxy_binary" | cut -d ' ' -f 1)"
if [ "$actual_sha256" != "$expected_sha256" ]; then
  echo "IPtProxy binary checksum mismatch: $actual_sha256" >&2
  exit 1
fi
    SCRIPT
    :execution_position => :before_compile,
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
