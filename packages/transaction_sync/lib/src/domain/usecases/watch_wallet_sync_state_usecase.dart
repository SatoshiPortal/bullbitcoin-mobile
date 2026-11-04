import '../repositories/wallet_transaction_repository.dart';
import '../wallet_network_key.dart';
import '../wallet_transaction_sync_state.dart';

class WatchWalletSyncStateUsecase {
  final WalletTransactionRepository repository;
  const WatchWalletSyncStateUsecase(this.repository);
  Stream<WalletTransactionSyncState> execute(WalletNetworkKey key) =>
      repository.watch(key);
}
