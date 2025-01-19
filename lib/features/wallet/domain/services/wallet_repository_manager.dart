import 'package:bb_mobile/features/wallet/data/repositories/bdk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/data/repositories/lwk_wallet_repository_impl.dart';
import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';

abstract class WalletRepositoryManager {
  void registerWallet(WalletMetadata metadata);
  WalletRepository? getRepository(String walletId);
  List<WalletRepository> getAllRepositories();
}

class WalletRepositoryManagerImpl implements WalletRepositoryManager {
  final Map<String, WalletRepository> _repositories = {};

  @override
  void registerWallet(WalletMetadata metadata) {
    final id = metadata.id;

    if (_repositories.containsKey(id)) {
      return;
    }

    _repositories[id] = _createRepository(metadata);
  }

  @override
  WalletRepository? getRepository(String id) {
    return _repositories[id];
  }

  @override
  List<WalletRepository> getAllRepositories() {
    return _repositories.values.toList();
  }

  WalletRepository _createRepository(WalletMetadata metadata) {
    switch (metadata.type) {
      case WalletType.bdk:
        return BdkWalletRepositoryImpl(metadata: metadata);
      case WalletType.lwk:
        return LwkWalletRepositoryImpl(metadata: metadata);
    }
  }
}
