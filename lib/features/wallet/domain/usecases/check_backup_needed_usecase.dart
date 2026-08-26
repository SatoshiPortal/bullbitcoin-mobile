import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// Determines whether the default wallets still need a backup.
class CheckBackupNeededUsecase {
  final GetWalletsUsecase _getWalletsUsecase;
  final Future<RecoverBullStatus> Function() _recoverBullStatus;

  CheckBackupNeededUsecase(this._getWalletsUsecase, this._recoverBullStatus);

  Future<bool> execute() async {
    final defaultWallets = await _getWalletsUsecase.execute(onlyDefaults: true);
    if (defaultWallets.isEmpty) return false;

    final status = await _recoverBullStatus();
    final hasVerifiedEncryptedBackup =
        status.isKnown && status.hasVerifiedEncryptedBackup;
    return defaultWallets.any(
      (wallet) => !hasVerifiedEncryptedBackup && !wallet.isPhysicalBackupTested,
    );
  }
}
