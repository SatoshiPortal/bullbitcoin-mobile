import '../wallet_sync_status.dart';
import '../wallet_sync_options_failure.dart';

abstract interface class WalletSyncStatusRepository {
  Stream<WalletSyncStatus> watch(String walletId);
  void invalidate(String walletId);
  void reportFailure(String walletId, WalletSyncOptionsFailure failure);
}
