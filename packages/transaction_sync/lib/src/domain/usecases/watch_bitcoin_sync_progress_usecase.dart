import '../entities/bitcoin_sync_progress.dart';
import '../wallet_network_key.dart';

final class WatchBitcoinSyncProgressUsecase {
  final BitcoinSyncProgressRepository _repository;

  const WatchBitcoinSyncProgressUsecase(this._repository);

  Stream<BitcoinSyncProgress> execute(WalletNetworkKey key) =>
      _repository.watchBitcoinSyncProgress(key);
}
