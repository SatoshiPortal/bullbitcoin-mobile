import 'package:freezed_annotation/freezed_annotation.dart';

part 'ip_address_entity.freezed.dart';

enum RequestMethod { get, post, put, delete, patch, head, options }

enum EncodingType { gzip, deflate, br, zstd }

@freezed
sealed class IpAddressEntity with _$IpAddressEntity {
  const factory IpAddressEntity({
    required String ipAddress,
    required String userAgent,
    required int port,
    required RequestMethod method,
    required List<EncodingType> supportedEncodings,
    required List<String> forwardedChain,
    required DateTime timestamp,
  }) = _IpAddressEntity;
  const IpAddressEntity._();

  bool get isCompressionSupported => supportedEncodings.isNotEmpty;

  bool get isSecureConnection => port == 443 || port == 8443;

  String get displayInfo => '$ipAddress:$port (${method.name.toUpperCase()})';

  bool get isMobileUserAgent =>
      userAgent.toLowerCase().contains('mobile') ||
      userAgent.toLowerCase().contains('android') ||
      userAgent.toLowerCase().contains('iphone') ||
      userAgent.toLowerCase().contains('ipad');
}
