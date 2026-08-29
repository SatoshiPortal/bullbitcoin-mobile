import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/synchronize_wallet_request.dart';
import '../entities/wallet_transaction_sync_outcome.dart';
import '../wallet_transaction_sync_failure.dart';

class SynchronizeWalletUsecase {
  final WalletTransactionRepository repository;
  const SynchronizeWalletUsecase(this.repository);
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  execute(SynchronizeWalletRequest request) => repository.synchronize(request);
}
