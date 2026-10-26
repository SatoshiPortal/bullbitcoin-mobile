import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/refresh_local_snapshot_request.dart';
import '../entities/wallet_transaction_sync_outcome.dart';
import '../wallet_transaction_sync_failure.dart';

class RefreshLocalSnapshotUsecase {
  final WalletTransactionRepository repository;
  const RefreshLocalSnapshotUsecase(this.repository);
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  execute(RefreshLocalSnapshotRequest request) => repository.refresh(request);
}
