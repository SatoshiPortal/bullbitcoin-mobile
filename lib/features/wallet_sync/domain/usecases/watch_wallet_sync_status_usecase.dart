import '../repositories/wallet_sync_status_repository.dart';
import '../wallet_sync_status.dart';

class WatchWalletSyncStatusUsecase {
  final WalletSyncStatusRepository _repository;
  const WatchWalletSyncStatusUsecase({required this._repository});
  Stream<WalletSyncStatus> execute(String walletId) =>
      _repository.watch(walletId);
}
