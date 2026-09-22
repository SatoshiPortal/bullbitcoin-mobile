import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

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
      final defaultWallets = switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        Ok(:final value) => value,
        // TODO(#1895): test_wallet_backup has no failure family yet. Map
        // WalletFailure into it instead of throwing once it does.
        Err(:final failure) => throw WalletFailureException(failure),
      };
      if (defaultWallets.isEmpty) {
        return false; // No default wallets found, so also no backup possible
      }

      bool hasBackup = false;
      for (final defaultWallet in defaultWallets) {
        hasBackup =
            defaultWallet.isPhysicalBackupTested ||
            defaultWallet.isEncryptedVaultTested;

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
