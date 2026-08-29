import 'wallet_transaction_snapshot.dart';

class MetadataPersistenceWarning {
  final String message;
  const MetadataPersistenceWarning([
    this.message = 'Metadata persistence failed',
  ]);
}

class WalletTransactionSyncOutcome {
  final WalletTransactionSnapshot snapshot;
  final MetadataPersistenceWarning? warning;
  const WalletTransactionSyncOutcome(this.snapshot, {this.warning});
}
