import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/services/wallet_repository_manager.dart';

class InitWalletsUseCase {
  final WalletRepositoryManager _repositoryManager;

  InitWalletsUseCase({
    required WalletRepositoryManager repositoryManager,
  }) : _repositoryManager = repositoryManager;

  Future<void> execute(List<WalletMetadata> walletsMetadata) async {
    for (final metadata in walletsMetadata) {
      _repositoryManager.registerWallet(metadata);
    }
  }
}
