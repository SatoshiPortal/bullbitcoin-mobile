import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletFailure extends Failure {
  const WalletFailure([super.logMessage]);
}

final class WalletTransactionLookupFailure extends WalletFailure {
  const WalletTransactionLookupFailure([super.logMessage]);
}

enum BitcoinSigningFailureKind {
  invalidPsbt,
  walletMismatch,
  missingLocalOrigin,
  missingUtxo,
  frozenUtxo,
  unsupportedSighash,
  unsupportedSpendMode,
  unsupportedPolicyPath,
  incomplete,
  unexpected,
}

final class BitcoinSigningFailure extends WalletFailure {
  final BitcoinSigningFailureKind kind;

  const BitcoinSigningFailure(this.kind, [super.logMessage]);
}
