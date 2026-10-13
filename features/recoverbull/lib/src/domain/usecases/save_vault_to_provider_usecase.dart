import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/pending_vault_backup.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_lifecycle_port.dart';
import 'google_drive/connect_google_drive_usecase.dart';
import 'google_drive/save_to_google_drive_usecase.dart';
import 'register_monitored_backup_usecase.dart';
import 'save_file_to_system_usecase.dart';

final class SaveVaultToProviderUsecase {
  final LogSink log;
  final SaveFileToSystemUsecase saveFile;
  final ConnectToGoogleDriveUsecase connectDrive;
  final SaveVaultToGoogleDriveUsecase saveDrive;
  final RegisterMonitoredBackupUsecase? registerBackup;
  final RecoverBullLifecyclePort? lifecycle;

  const SaveVaultToProviderUsecase({
    required this.log,
    required this.saveFile,
    required this.connectDrive,
    required this.saveDrive,
    this.registerBackup,
    this.lifecycle,
  });

  Future<Result<PendingVaultBackup, RecoverBullFailure>> execute({
    required PendingVaultBackup pending,
    required VaultProvider provider,
    required bool Function() cancelled,
  }) async {
    try {
      final Result<Null, RecoverBullFailure> saved;
      switch (provider) {
        case VaultProvider.customLocation:
          saved = await saveFile.execute(vault: pending.vault);
        case VaultProvider.googleDrive:
          final connected = await connectDrive.execute();
          if (connected is Err || cancelled()) {
            return const Err(VaultProviderSaveFailure());
          }
          saved = await saveDrive.execute(pending.vault);
        case VaultProvider.iCloud:
          return const Err(SelectVaultFailure());
      }
      if (saved is Err || cancelled()) {
        return const Err(VaultProviderSaveFailure());
      }
      // Advisory writes cannot change a successful external save into a failure.
      try {
        final registration = await registerBackup?.execute(
          backupIdHex: pending.vault.id,
        );
        if (registration is Err) {
          log.warning('recoverbull.attempts.monitoring.registration.failed');
        }
      } on Exception {
        log.warning('recoverbull.attempts.monitoring.registration.failed');
      }
      if (cancelled()) return const Err(VaultProviderSaveFailure());
      try {
        await lifecycle?.markStored(pending.network);
      } on Exception {
        log.warning('recoverbull.lifecycle.mark_stored_failed');
      }
      return Ok(pending);
    } on Exception {
      log.warning('recoverbull.vault.provider.save.unexpected');
      return const Err(VaultProviderSaveFailure());
    }
  }
}
