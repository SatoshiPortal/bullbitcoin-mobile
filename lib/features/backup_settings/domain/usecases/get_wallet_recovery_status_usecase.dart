import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';

final class GetWalletRecoveryStatusUsecase {
  final GetWalletsUsecase _getWallets;

  const GetWalletRecoveryStatusUsecase(this._getWallets);

  Future<Result<Wallet, BackupSettingsFailure>> execute() async {
    try {
      return switch (await _getWallets.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      )) {
        Ok(:final value) when value.length == 1 => Ok(value.single),
        _ => const Err(BackupSettingsUnexpectedFailure()),
      };
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }
}
