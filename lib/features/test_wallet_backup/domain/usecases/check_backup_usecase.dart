import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class CheckBackupUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final RecoverBullFeature _recoverBull;

  CheckBackupUsecase({
    required this._walletRepository,
    required this._settingsRepository,
    required this._recoverBull,
  });

  Future<bool> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );
      if (defaultWallets.isEmpty) {
        return false; // No default wallets found, so also no backup possible
      }

      final recoverBullStatus = await _recoverBull.status();
      bool hasBackup = recoverBullStatus.hasVerifiedEncryptedBackup;
      for (final defaultWallet in defaultWallets) {
        hasBackup = defaultWallet.isPhysicalBackupTested || hasBackup;

        if (hasBackup) {
          // Exit early if we found a backup, since the default
          //  wallets use the same seed, one backup is enough
          break;
        }
      }
      return hasBackup;
    } catch (e) {
      return false; // If any error occurs, we assume backup is not complete
    }
  }
}
