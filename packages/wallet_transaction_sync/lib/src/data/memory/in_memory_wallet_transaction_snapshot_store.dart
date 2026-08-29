import '../../domain/entities/wallet_transaction_snapshot.dart';
import '../../domain/wallet_network_key.dart';

final class InMemoryWalletTransactionSnapshotStore {
  final Map<WalletNetworkKey, WalletTransactionSnapshot> _snapshots = {};
  WalletTransactionSnapshot? read(WalletNetworkKey key) => _snapshots[key];
  void publish(WalletTransactionSnapshot snapshot) {
    _snapshots[snapshot.key] = snapshot;
  }

  void evict(WalletNetworkKey key) {
    _snapshots.remove(key);
  }
}
