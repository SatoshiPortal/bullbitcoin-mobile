import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckBackupUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CheckBackupUsecase({
    required this._walletRepository,
    required this._settingsRepository,
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

      final bitcoin = defaultWallets.where((wallet) => wallet.isBitcoin).first;
      return bitcoin.latestPhysicalBackup != null ||
          bitcoin.latestEncryptedBackup != null;
    } catch (e) {
      return false; // If any error occurs, we assume backup is not complete
    }
  }
}
