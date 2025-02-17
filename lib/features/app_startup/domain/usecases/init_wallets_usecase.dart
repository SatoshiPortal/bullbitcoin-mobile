import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class InitWalletsUseCase {
  final WalletRepositoryManager _walletManager;

  InitWalletsUseCase({
    required WalletRepositoryManager walletManager,
  }) : _walletManager = walletManager;

  Future<void> execute(List<WalletMetadata> walletsMetadata) async {
    for (final metadata in walletsMetadata) {
      _walletManager.registerWallet(metadata);
    }
  }
}
