import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class GetWalletsUseCase {
  final WalletRepositoryManager _manager;
  final WalletMetadataRepository _walletMetadataRepository;

  GetWalletsUseCase(
      {required WalletRepositoryManager walletRepositoryManager,
      required WalletMetadataRepository walletMetadataRepository})
      : _manager = walletRepositoryManager,
        _walletMetadataRepository = walletMetadataRepository;

  Future<List<Wallet>> execute() async {
    // todo: get the balance of each wallet, as well as metadata
    final walletRepositories = _manager.getAllRepositories();

    final wallets = <Wallet>[];
    for (final walletRepository in walletRepositories) {
      final walletMetadata = await _walletMetadataRepository
          .getWalletMetadata(walletRepository.id);

      if (walletMetadata == null) {
        continue;
      }

      final balance = await walletRepository.getBalance();

      wallets.add(
        Wallet(
          id: walletRepository.id,
          name: walletMetadata.name,
          balanceSat: balance.totalSat,
          network: walletMetadata.network,
        ),
      );
    }

    return wallets;
  }
}
