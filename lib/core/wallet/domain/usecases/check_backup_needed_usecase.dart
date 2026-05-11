import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

/// Reads from the wallet repo directly so callers can verify backup state
/// against the DB rather than a potentially-stale bloc cache.
class CheckBackupNeededUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CheckBackupNeededUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    final settings = await _settingsRepository.fetch();
    final defaultWallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: settings.environment,
    );

    return defaultWallets.isNotEmpty &&
        defaultWallets.any(
          (wallet) =>
              !wallet.isEncryptedVaultTested && !wallet.isPhysicalBackupTested,
        );
  }
}
