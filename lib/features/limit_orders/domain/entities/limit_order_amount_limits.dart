import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';

enum LimitOrderAmountViolationKind { belowMinimum, aboveMaximum }

final class LimitOrderAmountViolation {
  final LimitOrderAmountViolationKind kind;
  final LimitOrderWalletType network;
  final double boundBtc;

  const LimitOrderAmountViolation({
    required this.kind,
    required this.network,
    required this.boundBtc,
  });
}

/// Per-network buy limits mirrored from the Bull Bitcoin exchange configuration
/// (MIN_LIMIT_BUY_ON_CHAIN_SATS, MIN_LIMIT_BUY_LIQUID_SATS,
/// MAX_LIMIT_BUY_LN_INVOICE_SATS). Bitcoin and Liquid carry a minimum; Lightning
/// carries a maximum.
abstract final class LimitOrderAmountLimits {
  static const int minOnChainSats = 100000;
  static const int minLiquidSats = 1000;
  static const int maxLightningSats = 25000000;
  static const int _satsPerBtc = 100000000;

  /// Returns the violation for the destination [network], or null when the
  /// order amount is within limits. [fiatAmount] and [userPrice] are the same
  /// fiat unit; the amount is converted to sats at the user price.
  static LimitOrderAmountViolation? check({
    required double fiatAmount,
    required double userPrice,
    required LimitOrderWalletType network,
  }) {
    if (fiatAmount <= 0 || userPrice <= 0) return null;
    final sats = (fiatAmount / userPrice * _satsPerBtc).round();
    switch (network) {
      case LimitOrderWalletType.bitcoin:
        if (sats < minOnChainSats) {
          return _below(network, minOnChainSats);
        }
      case LimitOrderWalletType.liquid:
        if (sats < minLiquidSats) {
          return _below(network, minLiquidSats);
        }
      case LimitOrderWalletType.lightning:
        if (sats > maxLightningSats) {
          return LimitOrderAmountViolation(
            kind: LimitOrderAmountViolationKind.aboveMaximum,
            network: network,
            boundBtc: maxLightningSats / _satsPerBtc,
          );
        }
    }
    return null;
  }

  static LimitOrderAmountViolation _below(
    LimitOrderWalletType network,
    int boundSats,
  ) => LimitOrderAmountViolation(
    kind: LimitOrderAmountViolationKind.belowMinimum,
    network: network,
    boundBtc: boundSats / _satsPerBtc,
  );
}
