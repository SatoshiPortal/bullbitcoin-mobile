import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class CheckBackupUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Future<RecoverBullStatus> Function(RecoverBullNetwork)
  _recoverBullStatus;

  CheckBackupUsecase({
    required this._walletRepository,
    required this._settingsRepository,
    required this._recoverBullStatus,
  });

  @useResult
  Future<Result<bool, TestWalletBackupFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final List<Wallet> defaultWallets;
      switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      )) {
        case Ok(:final value):
          defaultWallets = value;
        // The wallet repository already logged the raw reason.
        case Err(:final failure):
          return Err(
            TestWalletBackupWalletsUnavailableFailure(failure.logMessage),
          );
      }
      if (defaultWallets.isEmpty) return const Ok(false);

      final recoverBullStatus = await _recoverBullStatus(
        settings.environment.isTestnet
            ? RecoverBullNetwork.testnet
            : RecoverBullNetwork.mainnet,
      );
      if (recoverBullStatus.hasVerifiedEncryptedBackup) return const Ok(true);
      for (final defaultWallet in defaultWallets) {
        if (defaultWallet.isPhysicalBackupTested) {
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
