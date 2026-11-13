import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';
import '../repositories/backup_metadata_repository.dart';
import '../repositories/google_drive_repository.dart';
import '../repositories/vault_repository.dart';

/// Silent, bounded to the current Drive account and current server consent.
/// File contents live only long enough to validate and hash their identifiers.
final class DiscoverDriveBackupsUsecase {
  final GoogleDriveRepository _drive;
  final VaultRepository _vaults;
  final BackupMetadataRepository _metadata;
  final AttemptMonitoringRepository _monitoring;

  const DiscoverDriveBackupsUsecase(
    this._drive,
    this._vaults,
    this._metadata,
    this._monitoring,
  );

  Future<Result<void, RecoverBullFailure>> execute() async {
    switch (await _metadata.settings()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (!value.permissionGranted || !value.monitoringEnabled) {
          return const Ok(null);
        }
        try {
          return await _drive.withDiscoverySession((session) async {
            if (session == null) return const Ok(null);
            for (final file in await session.fetchAllMetadata()) {
              final content = await session.fetchRawFile(file.id);
              switch (_vaults.parse(content)) {
                case Err():
                  continue;
                case Ok(value: final vault):
                  final registered = await session.withCurrentAccount(
                    () => _monitoring.register(value, vault),
                  );
                  if (registered case Err(:final failure)) return Err(failure);
              }
            }
            return const Ok(null);
          });
        } on Exception {
          log.warning('recoverbull.drive.discovery.failed');
          return const Err(RecoverBullUnexpectedFailure());
        }
    }
  }
}
