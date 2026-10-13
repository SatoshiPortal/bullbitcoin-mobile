import 'package:primitives/primitives.dart';

import '../entities/encrypted_vault.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_flow_failure.dart';
import 'google_drive/connect_google_drive_usecase.dart';
import 'google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'pick_vault_usecase.dart';

final class SelectVaultUsecase {
  final PickVaultUsecase pick;
  final ConnectToGoogleDriveUsecase connectDrive;
  final FetchLatestGoogleDriveVaultUsecase latestDrive;

  const SelectVaultUsecase({
    required this.pick,
    required this.connectDrive,
    required this.latestDrive,
  });

  Future<Result<EncryptedVault, RecoverBullFailure>> execute({
    required VaultProvider provider,
    required bool Function() cancelled,
  }) async {
    if (provider == VaultProvider.iCloud) {
      return const Err(SelectVaultFailure());
    }
    if (provider == VaultProvider.googleDrive) {
      final connected = await connectDrive.execute();
      if (connected case Err(:final failure)) {
        return Err(selectVaultFailure(failure));
      }
      if (cancelled()) return const Err(SelectVaultFailure());
      return (await latestDrive.execute()).mapErr(selectVaultFailure);
    }
    return (await pick.execute()).mapErr(selectVaultFailure);
  }
}
