import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CheckBackupUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CheckBackupUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<bool, TestWalletBackupFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );
      if (defaultWallets.isEmpty) return const Ok(false);

      for (final defaultWallet in defaultWallets) {
        if (defaultWallet.isPhysicalBackupTested ||
            defaultWallet.isEncryptedVaultTested) {
          // Exit early: the default wallets share a seed, so one backup is
          // enough.
          return const Ok(true);
        }
      }
      return const Ok(false);
    } on Object catch (e, st) {
      log.warning(
        'Failed to check whether a backup exists',
        error: e,
        trace: st,
      );
      return Err(TestWalletBackupWalletsUnavailableFailure(e.toString()));
    }
  }
}
