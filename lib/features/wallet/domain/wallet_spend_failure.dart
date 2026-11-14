import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSpendStatus;

sealed class WalletSpendFailure extends Failure {
  const WalletSpendFailure();
}

final class WalletSpendBlockedFailure extends WalletSpendFailure {
  final BitcoinSpendStatus status;
  const WalletSpendBlockedFailure(this.status);
}

/// Compatibility seam for existing throwing PSBT builders. New callers use
/// the public readiness result; presentation maps this to its feature failure.
final class WalletSpendBlockedException implements Exception {
  final BitcoinSpendStatus status;
  const WalletSpendBlockedException(this.status);
}
