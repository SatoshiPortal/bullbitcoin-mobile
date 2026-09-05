import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../requests/discover_wallet_history_request.dart';
import '../entities/wallet_transaction_sync_outcome.dart';
import '../wallet_transaction_sync_failure.dart';

class DiscoverWalletHistoryUsecase {
  final WalletTransactionRepository repository;
  const DiscoverWalletHistoryUsecase(this.repository);
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  execute(DiscoverWalletHistoryRequest request) => repository.discover(request);
}
