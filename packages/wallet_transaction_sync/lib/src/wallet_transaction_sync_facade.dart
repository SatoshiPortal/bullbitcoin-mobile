import 'domain/entities/wallet_transaction_observation.dart';
import 'domain/entities/wallet_transaction_page.dart';
import 'domain/entities/wallet_transaction_sync_outcome.dart';
import 'domain/requests/requests.dart';
import 'domain/wallet_network_key.dart';
import 'domain/wallet_transaction_sync_failure.dart';
import 'data/wallet_transaction_repository_impl.dart';
import 'domain/wallet_transaction_sync_state.dart';
import 'domain/ports/wallet_transaction_source_port.dart';
import 'domain/ports/wallet_sync_metadata_port.dart';
import 'wallet_source_operation_coordinator.dart';
import 'domain/usecases/synchronize_wallet_usecase.dart';
import 'domain/usecases/discover_wallet_history_usecase.dart';
import 'domain/usecases/refresh_local_snapshot_usecase.dart';
import 'domain/usecases/lookup_local_transaction_usecase.dart';
import 'domain/usecases/list_local_transactions_usecase.dart';
import 'domain/usecases/watch_wallet_sync_state_usecase.dart';
import 'domain/usecases/delete_wallet_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class WalletTransactionSyncFacade {
  late final WalletTransactionRepositoryImpl _repository;
  late final SynchronizeWalletUsecase _synchronize;
  late final DiscoverWalletHistoryUsecase _discover;
  late final RefreshLocalSnapshotUsecase _refresh;
  late final LookupLocalTransactionUsecase _lookup;
  late final ListLocalTransactionsUsecase _list;
  late final WatchWalletSyncStateUsecase _watch;
  late final DeleteWalletUsecase _delete;

  WalletTransactionSyncFacade({
    required WalletTransactionSourcePort source,
    required WalletSyncMetadataPort metadata,
    required WalletSourceOperationCoordinator coordinator,
    DateTime Function()? now,
  }) {
    _repository = WalletTransactionRepositoryImpl(
      source: source,
      metadata: metadata,
      coordinator: coordinator,
      now: now,
    );
    _synchronize = SynchronizeWalletUsecase(_repository);
    _discover = DiscoverWalletHistoryUsecase(_repository);
    _refresh = RefreshLocalSnapshotUsecase(_repository);
    _lookup = LookupLocalTransactionUsecase(_repository);
    _list = ListLocalTransactionsUsecase(_repository);
    _watch = WatchWalletSyncStateUsecase(_repository);
    _delete = DeleteWalletUsecase(_repository);
  }

  /// Closes every state stream. For application shutdown; watchers complete
  /// and the facade must not be used for watching afterwards.
  Future<void> dispose() => _repository.dispose();

  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  synchronizeWallet(SynchronizeWalletRequest request) =>
      _synchronize.execute(request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  discoverWalletHistory(DiscoverWalletHistoryRequest request) =>
      _discover.execute(request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  refreshLocalSnapshot(RefreshLocalSnapshotRequest request) =>
      _refresh.execute(request);
  @useResult
  Future<Result<WalletTransactionObservation?, WalletTransactionSyncFailure>>
  lookupLocal(LookupLocalTransactionRequest request) =>
      _lookup.execute(request);
  @useResult
  Future<Result<WalletTransactionPage, WalletTransactionSyncFailure>> listLocal(
    ListLocalTransactionsRequest request,
  ) => _list.execute(request);
  Stream<WalletTransactionSyncState> watchWalletState(WalletNetworkKey key) =>
      _watch.execute(key);
  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> deleteWallet(
    WalletNetworkKey key,
  ) => _delete.execute(key);
}
