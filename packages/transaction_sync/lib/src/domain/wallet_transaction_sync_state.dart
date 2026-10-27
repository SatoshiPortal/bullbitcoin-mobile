import 'entities/wallet_transaction_sync_outcome.dart';
import 'wallet_transaction_sync_failure.dart';

sealed class WalletTransactionSyncState {
  final int? previousRevision;
  const WalletTransactionSyncState(this.previousRevision);
}

final class WalletStateUninitialized extends WalletTransactionSyncState {
  const WalletStateUninitialized() : super(null);
}

final class WalletStateLoadingLocal extends WalletTransactionSyncState {
  const WalletStateLoadingLocal(int? r) : super(r);
}

final class WalletStateSyncing extends WalletTransactionSyncState {
  const WalletStateSyncing(int? r) : super(r);
}

final class WalletStateReady extends WalletTransactionSyncState {
  final int revision;
  final DateTime? freshness;
  const WalletStateReady(this.revision, this.freshness) : super(revision);
}

final class WalletStateReadyWithWarning extends WalletStateReady {
  final DateTime? nonDurableObservedAt;
  final MetadataPersistenceWarning warning;

  const WalletStateReadyWithWarning(
    int revision,
    this.nonDurableObservedAt,
    this.warning,
  ) : super(revision, null);
}

final class WalletStateFailed extends WalletTransactionSyncState {
  final WalletTransactionSyncFailure failure;
  final DateTime? freshness;
  const WalletStateFailed(int? previousRevision, this.failure, this.freshness)
    : super(previousRevision);
}

final class WalletStateRegistrationMismatch extends WalletTransactionSyncState {
  const WalletStateRegistrationMismatch(int? r) : super(r);
}

final class WalletStateDeleted extends WalletTransactionSyncState {
  const WalletStateDeleted() : super(null);
}
