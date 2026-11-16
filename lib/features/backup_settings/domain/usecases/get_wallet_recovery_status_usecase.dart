import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
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
