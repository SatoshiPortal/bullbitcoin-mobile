import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:meta/meta.dart';

class SamRockPairingRequest {
  final Uri protocolUri;
  final String storeId;
  final String otp;
  final Set<SamRockSetupCapability> setup;

  const SamRockPairingRequest._({
    required this.protocolUri,
    required this.storeId,
    required this.otp,
    required this.setup,
  });

  bool get supportsBitcoinChain =>
      setup.contains(SamRockSetupCapability.bitcoinChain);

  bool get supportsLiquidChain =>
      setup.contains(SamRockSetupCapability.liquidChain);

  bool get supportsLightning =>
      setup.contains(SamRockSetupCapability.bitcoinLightning);
}

enum SamRockSetupCapability {
  bitcoinChain('btc-chain'),
  liquidChain('liquid-chain'),
  bitcoinLightning('btc-ln');

  final String value;

  const SamRockSetupCapability(this.value);

  static SamRockSetupCapability? tryParse(String value) {
    return switch (value.trim().toLowerCase()) {
      'btc' || 'btc-chain' => SamRockSetupCapability.bitcoinChain,
      'lbtc' || 'liquid-chain' => SamRockSetupCapability.liquidChain,
      'btcln' || 'btc-ln' => SamRockSetupCapability.bitcoinLightning,
      _ => null,
    };
  }
}

class SamRockPairingRequestParser {
  const SamRockPairingRequestParser();

  @useResult
  Result<SamRockPairingRequest, BtcpayFailure> parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasAbsolutePath) {
      return const Err(
        InvalidBtcpayPairingRequestFailure('invalid or relative URI'),
      );
    }
    if (uri.scheme != 'https') {
      return const Err(InvalidBtcpayPairingRequestFailure('HTTPS is required'));
    }
    if (uri.host.trim().isEmpty) {
      return const Err(
        InvalidBtcpayPairingRequestFailure('server host is missing'),
      );
    }
    if (!uri.path.endsWith('/samrock/protocol')) {
      return const Err(
        InvalidBtcpayPairingRequestFailure('unsupported protocol path'),
      );
    }

    final storeId = _storeId(uri);
    if (storeId == null || storeId.isEmpty) {
      return const Err(
        InvalidBtcpayPairingRequestFailure('store ID is missing'),
      );
    }

    final otp = uri.queryParameters['otp']?.trim();
    if (otp == null || otp.isEmpty) {
      return const Err(InvalidBtcpayPairingRequestFailure('OTP is missing'));
    }

    final setup = _parseSetup(uri.queryParameters['setup']);
    if (setup == null || setup.isEmpty) {
      return const Err(
        InvalidBtcpayPairingRequestFailure(
          'setup capabilities are missing or unsupported',
        ),
      );
    }

    return Ok(
      SamRockPairingRequest._(
        protocolUri: uri,
        storeId: storeId,
        otp: otp,
        setup: Set.unmodifiable(setup),
      ),
    );
  }

  String? _storeId(Uri uri) {
    final segments = uri.pathSegments;
    final pluginsIndex = segments.indexOf('plugins');
    if (pluginsIndex < 0 || pluginsIndex + 3 >= segments.length) return null;
    if (segments[pluginsIndex + 2] != 'samrock') return null;
    if (segments[pluginsIndex + 3] != 'protocol') return null;
    return segments[pluginsIndex + 1].trim();
  }

  Set<SamRockSetupCapability>? _parseSetup(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().toLowerCase() == 'all') {
      return SamRockSetupCapability.values.toSet();
    }

    final setup = <SamRockSetupCapability>{};
    for (final rawCapability in value.split(',')) {
      final capability = SamRockSetupCapability.tryParse(rawCapability);
      if (capability == null) return null;
      setup.add(capability);
    }
    return setup;
  }
}
