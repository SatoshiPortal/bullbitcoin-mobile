import 'wallet_transaction_snapshot.dart';
import 'wallet_transaction.dart';

class MetadataPersistenceWarning {
  final String message;
  const MetadataPersistenceWarning([
    this.message = 'Metadata persistence failed',
  ]);
}

class WalletTransactionSyncOutcome {
  final WalletTransactionSnapshot snapshot;
  final List<WalletTransaction> newIncomingTransactions;
  final MetadataPersistenceWarning? warning;
  WalletTransactionSyncOutcome(
    this.snapshot, {
    List<WalletTransaction> newIncomingTransactions = const [],
    this.warning,
  }) : newIncomingTransactions = List.unmodifiable(newIncomingTransactions);
}
