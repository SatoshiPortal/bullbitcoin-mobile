import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class CheckBullVaultMobileBackupsUsecase {
  final TestWalletBackupFacade _testWalletBackupFacade;
  final RecoverBullFacade _recoverBullFacade;

  const CheckBullVaultMobileBackupsUsecase(
    this._testWalletBackupFacade,
    this._recoverBullFacade,
  );

  Future<Result<({bool physical, bool recoverBull}), BullVaultFailure>> execute(
    String fingerprint,
  ) async {
    try {
      final physical = await _testWalletBackupFacade.isPhysicalBackupVerified(
        fingerprint,
      );
      final recoverBull = await _recoverBullFacade.hasTestedBackup(fingerprint);
      return Ok((physical: physical, recoverBull: recoverBull));
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
