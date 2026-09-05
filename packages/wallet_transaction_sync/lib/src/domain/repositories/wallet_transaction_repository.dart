import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../entities/wallet_transaction_observation.dart';
import '../entities/wallet_transaction_page.dart';
import '../entities/wallet_transaction_sync_outcome.dart';
import '../requests/requests.dart';
import '../wallet_network_key.dart';
import '../wallet_transaction_sync_failure.dart';
import '../wallet_transaction_sync_state.dart';

abstract interface class WalletTransactionRepository {
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  refresh(RefreshLocalSnapshotRequest request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  synchronize(SynchronizeWalletRequest request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  discover(DiscoverWalletHistoryRequest request);
  @useResult
  Future<Result<WalletTransactionObservation?, WalletTransactionSyncFailure>>
  lookup(LookupLocalTransactionRequest request);
  @useResult
  Future<Result<WalletTransactionPage, WalletTransactionSyncFailure>> list(
    ListLocalTransactionsRequest request,
  );
  Stream<WalletTransactionSyncState> watch(WalletNetworkKey key);
  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
  );
}
