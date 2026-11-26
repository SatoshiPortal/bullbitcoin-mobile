import 'package:bull_ark/bull_ark.dart';
import 'package:primitives/primitives.dart';

import 'package:swaps/order_swaps.dart';

enum TransferWalletKind { bitcoin, liquid, ark }

/// Display and routing facts only. A selected wallet never grants authority.
final class TransferWallet {
  final String id;
  final String label;
  final TransferWalletKind kind;
  final BitcoinNetwork network;
  final BigInt? balance;
  final bool canSend;
  const TransferWallet({
    required this.id,
    required this.label,
    required this.kind,
    required this.network,
    required this.balance,
    required this.canSend,
  });
}

final class InternalTransfer {
  final TransferWallet from;
  final TransferWallet to;
  final ArkTransferContext ark;
  final String rawAmount;
  const InternalTransfer({
    required this.from,
    required this.to,
    required this.ark,
    required this.rawAmount,
  });

  bool get usesArk =>
      from.kind == TransferWalletKind.ark || to.kind == TransferWalletKind.ark;
  bool get isBoard =>
      from.kind == TransferWalletKind.bitcoin &&
      to.kind == TransferWalletKind.ark;
  BigInt? get amount => RegExp(r'^[0-9]+$').hasMatch(rawAmount)
      ? BigInt.tryParse(rawAmount)
      : null;
  BigInt? get minimum =>
      isBoard ? ark.snapshot.serverInfo?.minimumBoard?.value : null;

  SwapFailure? get failure {
    if (from.id == to.id ||
        !from.canSend ||
        from.network != to.network ||
        (from.kind == TransferWalletKind.liquid &&
            to.kind == TransferWalletKind.liquid)) {
      return const SwapUnsupportedNetworkFailure();
    }
    if (usesArk) {
      if (ark.snapshot.stale ||
          from.network != ark.config.id.network ||
          from.kind == TransferWalletKind.liquid ||
          to.kind == TransferWalletKind.liquid ||
          (isBoard && from.id != ark.boardSourceWalletId)) {
        return const SwapUnsupportedNetworkFailure();
      }
    }
    final value = amount;
    if (value == null ||
        value <= BigInt.zero ||
        value > BigInt.from(2100000000000000)) {
      return const SwapValidationFailure();
    }
    final lower = minimum;
    if (lower != null && value < lower) {
      return SwapAmountOutOfBoundsFailure(
        limitAmountSat: lower,
        isMinimum: true,
      );
    }
    final balance = from.balance;
    if (balance == null) return const SwapInvalidStateFailure();
    // The native quote checks fees and spendability; balance alone cannot.
    if (value > balance) {
      return SwapAmountOutOfBoundsFailure(
        limitAmountSat: balance,
        isMinimum: false,
      );
    }
    return null;
  }
}
