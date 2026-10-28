import 'package:primitives/primitives.dart';
import '../repositories/wallet_transaction_repository.dart';
import '../wallet_network_key.dart';
import '../wallet_transaction_sync_failure.dart';

class DeleteWalletUsecase {
  final WalletTransactionRepository repository;
  const DeleteWalletUsecase(this.repository);
  Future<Result<void, WalletTransactionSyncFailure>> execute(
    WalletNetworkKey key,
  ) => repository.delete(key);
}
