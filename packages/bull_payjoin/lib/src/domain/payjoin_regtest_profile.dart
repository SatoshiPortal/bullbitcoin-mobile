import 'dart:typed_data';
import 'dart:convert';

import 'package:primitives/primitives.dart';

import 'package:crypto/crypto.dart';

/// Explicit trust and endpoints for one captured regtest-only fixture.
/// Production runtimes never construct or load this profile.
final class PayjoinRegtestProfile {
  static const maximumCertificateBytes = 16 * 1024;

  /// Physical route only; protocol origins and TLS names remain logical.
  final LocalRegtestHost hostProfile;

  final Uint8List certificateDer;
  final String certificateSha256;

  PayjoinRegtestProfile({
    required this.hostProfile,
    required List<int> certificateDer,
    required String approvedCertificateSha256,
  }) : certificateDer = Uint8List.fromList(certificateDer).asUnmodifiableView(),
       certificateSha256 = sha256.convert(certificateDer).toString() {
    if (certificateDer.isEmpty ||
        certificateDer.length > maximumCertificateBytes ||
        certificateSha256 != approvedCertificateSha256) {
      throw const FormatException('Invalid regtest Payjoin certificate pin');
    }
  }

  factory PayjoinRegtestProfile.fromBuildEnvironment({
    required LocalRegtestHost hostProfile,
  }) => PayjoinRegtestProfile(
    hostProfile: hostProfile,
    certificateDer: base64Decode(
      const String.fromEnvironment('BULL_PAYJOIN_CERT_DER_BASE64'),
    ),
    approvedCertificateSha256: const String.fromEnvironment(
      'BULL_PAYJOIN_CERT_SHA256',
    ),
  );

  String get host => hostProfile.host;

  List<Uri> get servers => List.unmodifiable([
    Uri(scheme: 'https', host: 'localhost', port: 8040),
    Uri(scheme: 'https', host: '127.0.0.1', port: 8041),
  ]);

  bool allowsEndpoint(Uri endpoint) => allowsLogicalEndpoint(endpoint);

  static bool allowsLogicalEndpoint(Uri endpoint) =>
      endpoint.scheme == 'https' &&
      ((endpoint.host == 'localhost' && endpoint.port == 8040) ||
          (endpoint.host == '127.0.0.1' && endpoint.port == 8041)) &&
      endpoint.userInfo.isEmpty &&
      !endpoint.hasFragment;

  void requireEndpoint(Uri endpoint) {
    if (!allowsEndpoint(endpoint)) {
      throw const FormatException(
        'Endpoint does not match the regtest Payjoin profile',
      );
    }
  }

  /// Fixture only: both roles belong to one operator, on distinct fixed ports.
  /// This makes no production claim of OHTTP operator separation.
  List<Uri> relaysFor(Uri directory) {
    requireEndpoint(directory);
    return [
      for (final relay in servers)
        if (relay.port != directory.port) relay,
    ];
  }
}
