import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';

class GetWalletsUseCase {
  final SettingsRepository _settingsRepository;
  final WalletRepositoryManager _manager;
  final WalletMetadataRepository _walletMetadataRepository;

  GetWalletsUseCase(
      {required SettingsRepository settingsRepository,
      required WalletRepositoryManager walletRepositoryManager,
      required WalletMetadataRepository walletMetadataRepository})
      : _settingsRepository = settingsRepository,
        _manager = walletRepositoryManager,
        _walletMetadataRepository = walletMetadataRepository;

  Future<List<Wallet>> execute() async {
    // Only get wallets for the current environment
    final environment = await _settingsRepository.getEnvironment();
    final walletRepositories =
        _manager.getRepositories(environment: environment);

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
          isDefault: walletMetadata.isDefault,
        ),
      );
    }

    return wallets;
  }
}
