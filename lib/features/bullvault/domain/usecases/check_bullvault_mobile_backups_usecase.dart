import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Network;

class CheckBullVaultMobileBackupsUsecase {
  final TestWalletBackupFacade _testWalletBackupFacade;
  final Future<Result<BackupStatus, RecoverBullFailure>> Function(VaultContext)
  _backupStatus;

  const CheckBullVaultMobileBackupsUsecase(
    this._testWalletBackupFacade,
    this._backupStatus,
  );

  Future<Result<({bool physical, bool recoverBull}), BullVaultFailure>> execute(
    String fingerprint, {
    required Network network,
  }) async {
    try {
      final physical = await _testWalletBackupFacade.isPhysicalBackupVerified(
        fingerprint,
      );
      final identity = Fingerprint.tryParse(fingerprint);
      if (identity == null) return const Err(BullVaultBackupStatusFailure());
      final status = await _backupStatus(
        VaultContext(
          fingerprint: identity,
          network: network.isTestnet
              ? BitcoinNetwork.testnet
              : BitcoinNetwork.mainnet,
        ),
      );
      return switch (status) {
        Ok(:final value) => Ok((
          physical: physical,
          recoverBull: value.isVerified,
        )),
        Err() => const Err(BullVaultBackupStatusFailure()),
      };
    } on Exception catch (e, st) {
      log.severe(
        message: 'checkBullVaultMobileBackups failed',
        error: e,
        trace: st,
      );
      return const Err(BullVaultBackupStatusFailure());
    }
  }
}
