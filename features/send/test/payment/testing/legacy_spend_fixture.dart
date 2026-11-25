import 'package:primitives/legacy_exceptions.dart';
import 'package:spend/legacy_exceptions.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus;

class InsufficientFundsException extends BullException {
  InsufficientFundsException(super.message);
}

class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}

final class WalletSpendBlockedException implements Exception {
  final BitcoinSpendStatus status;

  const WalletSpendBlockedException(this.status);
}

enum BroadcastFailureCategory {
  rejected,
  alreadyInChain,
  connection,
  unexpected,
  authorization;

  static BroadcastFailureCategory of(Object error) =>
      error is CategorizedBroadcastException
      ? error.category
      : BroadcastFailureCategory.unexpected;
}

final class CategorizedBroadcastException
    extends BroadcastTransactionException {
  final BroadcastFailureCategory category;

  CategorizedBroadcastException(this.category)
    : super('send_broadcast_failed category=${category.name}');
}
