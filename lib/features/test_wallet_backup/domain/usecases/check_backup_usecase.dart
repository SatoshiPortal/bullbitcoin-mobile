import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CheckBackupUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Future<rb.Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _backupStatus;

  CheckBackupUsecase({
    required this._walletRepository,
    required this._settingsRepository,
    required this._backupStatus,
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

      for (final defaultWallet in defaultWallets) {
        if (defaultWallet.isPhysicalBackupTested) {
          // Exit early: the default wallets share a seed, so one backup is
          // enough.
          return const Ok(true);
        }
      }
      final bitcoin = defaultWallets
          .where((wallet) => wallet.network.isBitcoin)
          .firstOrNull;
      if (bitcoin == null) return const Ok(false);
      return switch (await _backupStatus(
        rb.VaultContext(
          fingerprint: rb.Fingerprint(bitcoin.masterFingerprint),
          network: bitcoin.network.isTestnet
              ? rb.BitcoinNetwork.testnet
              : rb.BitcoinNetwork.mainnet,
        ),
      )) {
        rb.Ok(:final value) => Ok(value.isVerified),
        rb.Err() => const Err(TestWalletBackupWalletsUnavailableFailure()),
      };
    } on Exception {
      log.warning('recoverbull.backup.status.unavailable');
      return Err(const TestWalletBackupWalletsUnavailableFailure());
    }
  }
}
