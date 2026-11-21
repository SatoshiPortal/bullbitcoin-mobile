import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinRegtestProfile;
import 'package:primitives/primitives.dart' as primitives;
import 'package:sync/sync.dart' as native show validateAddress;

/// Validates the captured concrete environment before legacy parsing can
/// collapse it into a testnet boolean. No raw input enters diagnostics.
class DetectBitcoinStringUsecase {
  final GetSettingsUsecase? _settings;

  DetectBitcoinStringUsecase({this._settings});

  Future<PaymentRequest> execute({
    required String data,
    primitives.NetworkEnv? environment,
  }) async {
    final active = environment ?? (await _settings?.execute())?.activeNetwork;
    final input = data.trim();
    final uri = Uri.tryParse(input);
    final address = uri?.scheme.toLowerCase() == 'bitcoin'
        ? uri?.path ?? ''
        : input;
    final lower = address.toLowerCase();
    if (active == primitives.NetworkEnv.signet) {
      throw const FormatException('Unsupported payment network');
    }
    final raw = input.toLowerCase();
    final regtestInvoice =
        raw.startsWith('lnbcrt') || raw.startsWith('lightning:lnbcrt');
    final regtestLiquid = raw.startsWith('el1') || raw.startsWith('ert1');
    if (regtestInvoice || regtestLiquid) {
      if (active != primitives.NetworkEnv.regtest) {
        throw const FormatException('Unsupported payment network');
      }
      if (regtestInvoice) return PaymentRequest.parse(input);
      if (await native.validateAddress(input, primitives.LiquidNetwork.regtest)
          is primitives.Err) {
        throw const FormatException('Invalid regtest destination');
      }
      return PaymentRequest.bip21(
        network: Network.liquidRegtest,
        uri: input,
        address: input,
      );
    }
    if (active == primitives.NetworkEnv.regtest || lower.startsWith('bcrt1')) {
      if (active != primitives.NetworkEnv.regtest) {
        throw const FormatException('Payment network mismatch');
      }
      final validated = await native.validateAddress(
        address,
        primitives.BitcoinNetwork.regtest,
      );
      if (validated is primitives.Err) {
        throw const FormatException('Invalid regtest destination');
      }
      int? amountSat;
      var label = '';
      var message = '';
      if (uri != null && uri.scheme.toLowerCase() == 'bitcoin') {
        final parameters = uri.queryParametersAll;
        if (parameters.values.any((values) => values.length != 1) ||
            parameters.keys.any(
              (key) => key.startsWith('req-') || key == 'lightning',
            )) {
          throw const FormatException('Unsupported payment parameters');
        }
        final pj = uri.queryParameters['pj'];
        final pjos = uri.queryParameters['pjos'];
        if ((pj != null &&
                !PayjoinRegtestProfile.allowsLogicalEndpoint(
                  Uri.parse(pj).removeFragment(),
                )) ||
            (pjos != null && (pj == null || (pjos != '0' && pjos != '1')))) {
          throw const FormatException('Unsupported Payjoin endpoint');
        }
        final amount = uri.queryParameters['amount'];
        if (amount != null) {
          if (!RegExp(r'^\d+(\.\d{1,8})?$').hasMatch(amount)) {
            throw const FormatException('Invalid payment amount');
          }
          final parts = amount.split('.');
          final sats =
              BigInt.parse(parts.first) * BigInt.from(100000000) +
              BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(8, '0'));
          if (sats > BigInt.from(2100000000000000)) {
            throw const FormatException('Invalid payment amount');
          }
          amountSat = sats.toInt();
        }
        try {
          final decoded = bip21.decode(input);
          label = PaymentRequest.sanitizePaymentLabel(decoded.label ?? '');
          message = PaymentRequest.sanitizePaymentLabel(decoded.message ?? '');
        } on String {
          throw const FormatException('Invalid payment URI');
        }
      }
      return PaymentRequest.bip21(
        network: Network.bitcoinRegtest,
        uri: input,
        address: address,
        amountSat: amountSat,
        label: label,
        message: message,
        pj: uri?.queryParameters['pj'] ?? '',
        pjos: uri?.queryParameters['pjos'] ?? '',
      );
    }
    final request = await PaymentRequest.parse(input);
    final (destination, network) = switch (request) {
      BitcoinPaymentRequest(:final address, :final isTestnet) => (
        address,
        isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
      ),
      LiquidPaymentRequest(:final address, :final isTestnet) => (
        address,
        isTestnet ? Network.liquidTestnet : Network.liquidMainnet,
      ),
      Bip21PaymentRequest(:final address, :final network) => (address, network),
      _ => (null, null),
    };
    if (destination != null && network != null) {
      if (active != null && network.environment != active) {
        throw const FormatException('Payment network mismatch');
      }
      if (await native.validateAddress(destination, network.shared)
          is primitives.Err) {
        throw const FormatException('Invalid payment destination');
      }
    }
    return request;
  }
}
