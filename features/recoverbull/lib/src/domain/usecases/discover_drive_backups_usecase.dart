import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../entities/attempt_monitoring_state.dart';
import '../entities/monitored_backup.dart';
import '../entities/drive_backup_cache_entry.dart';
import 'package:bull_logger/bull_logger.dart';

import '../entities/attempt_monitoring_snapshot.dart';
import '../repositories/recoverbull_attempt_monitoring_repository.dart';
import '../recoverbull_drive_discovery_port.dart';

enum DriveDiscoveryStatus {
  unauthenticated,
  disabled,
  empty,
  complete,
  partial,
  failed,
}

final class DriveDiscoveryResult {
  final DriveDiscoveryStatus status;
  final int listed;
  final int monitored;
  final int invalid;
  final int failed;

  const DriveDiscoveryResult({
    required this.status,
    required this.listed,
    required this.monitored,
    required this.invalid,
    required this.failed,
  });

  bool get isPartial => status == DriveDiscoveryStatus.partial;
}

final class DiscoverDriveBackupsUsecase {
  final RecoverBullDriveDiscoveryPort drive;
  final RecoverBullAttemptMonitoringRepository store;
  final LogSink? log;

  const DiscoverDriveBackupsUsecase({
    required this.drive,
    required this.store,
    this.log,
  });

  Future<Result<DriveDiscoveryResult, RecoverBullFailure>> execute() async {
    try {
      return await _execute();
    } on Exception catch (_) {
      log?.warning('recoverbull.drive.discovery.failed');
      return const Ok(
        DriveDiscoveryResult(
          status: DriveDiscoveryStatus.failed,
          listed: 0,
          monitored: 0,
          invalid: 0,
          failed: 1,
        ),
      );
    }
  }

  Future<Result<DriveDiscoveryResult, RecoverBullFailure>> _execute() async {
    final storageResult1 = await store.state();
    if (storageResult1 case Err(:final failure)) return Err(failure);
    if (!((storageResult1 as Ok<AttemptMonitoringState, RecoverBullFailure>)
            .value)
        .attemptMonitoringEnabled) {
      return const Ok(
        DriveDiscoveryResult(
          status: DriveDiscoveryStatus.disabled,
          listed: 0,
          monitored: 0,
          invalid: 0,
          failed: 0,
        ),
      );
    }
    return drive.withDiscoverySession((session) async {
      if (session == null) {
        return const Ok(
          DriveDiscoveryResult(
            status: DriveDiscoveryStatus.unauthenticated,
            listed: 0,
            monitored: 0,
            invalid: 0,
            failed: 0,
          ),
        );
      }
      final account = session.account;
      final List<RecoverBullDriveFile> files;
      try {
        files = await session.files();
      } on Exception catch (_) {
        log?.warning('recoverbull.drive.discovery.failed');
        return const Ok(
          DriveDiscoveryResult(
            status: DriveDiscoveryStatus.failed,
            listed: 0,
            monitored: 0,
            invalid: 0,
            failed: 1,
          ),
        );
      }
      if (files.isEmpty) {
        final storageResult2 = await session.withCurrentAccount(
          () => store.reconcileDriveBackups(account, const []),
        );
        if (storageResult2 case Err(:final failure)) return Err(failure);
        final applied = (storageResult2 as Ok<bool, RecoverBullFailure>).value;
        if (!applied) return const Ok(_disabledResult);
        return const Ok(
          DriveDiscoveryResult(
            status: DriveDiscoveryStatus.empty,
            listed: 0,
            monitored: 0,
            invalid: 0,
            failed: 0,
          ),
        );
      }

      final storageResult3 = await store.driveCache(account);
      if (storageResult3 case Err(:final failure)) return Err(failure);
      final cache =
          (storageResult3
                  as Ok<List<DriveBackupCacheEntry>, RecoverBullFailure>)
              .value;
      final storageResult4 = await store.monitoredBackups();
      if (storageResult4 case Err(:final failure)) return Err(failure);
      final monitored =
          (storageResult4 as Ok<List<MonitoredBackup>, RecoverBullFailure>)
              .value;
      final monitoredDigests = {for (final row in monitored) _key(row.digest)};
      final observations = <DriveBackupObservation>[];
      var invalid = 0;
      var failed = 0;
      for (final file in files) {
        final old = cache
            .where((row) => row.driveFileId == file.id)
            .firstOrNull;
        if (old != null &&
            old.driveFileModifiedAt == file.modifiedTime &&
            monitoredDigests.contains(_key(old.backupDigest))) {
          observations.add(
            DriveBackupObservation(
              fileId: file.id,
              digest: old.backupDigest,
              createdAt: file.createdTime,
              modifiedAt: file.modifiedTime,
            ),
          );
          continue;
        }
        final result = await session.content(file.id);
        switch (result) {
          case Ok(:final value):
            observations.add(
              DriveBackupObservation(
                fileId: file.id,
                digest: store.digestFor(_decode(value.id)),
                createdAt: file.createdTime,
                modifiedAt: file.modifiedTime,
              ),
            );
          case Err(:final failure):
            if (failure is InvalidVaultFileFailure) {
              invalid++;
            } else {
              failed++;
            }
            if (old != null) {
              observations.add(
                DriveBackupObservation(
                  fileId: file.id,
                  digest: old.backupDigest,
                  createdAt: old.driveFileCreatedAt,
                  modifiedAt: old.driveFileModifiedAt,
                ),
              );
            }
        }
      }

      final storageResult5 = await session.withCurrentAccount(
        () => store.reconcileDriveBackups(account, observations),
      );
      if (storageResult5 case Err(:final failure)) return Err(failure);
      final applied = (storageResult5 as Ok<bool, RecoverBullFailure>).value;
      if (!applied) return const Ok(_disabledResult);
      final status = failed > 0 || invalid > 0
          ? DriveDiscoveryStatus.partial
          : DriveDiscoveryStatus.complete;
      if (status == DriveDiscoveryStatus.partial) {
        log?.warning(
          'recoverbull.drive.discovery.partial listed=${files.length} '
          'monitored=${{for (final item in observations) item.digestKey}.length} '
          'invalid=$invalid failed=$failed',
        );
      }
      return Ok(
        DriveDiscoveryResult(
          status: status,
          listed: files.length,
          monitored: {for (final item in observations) item.digestKey}.length,
          invalid: invalid,
          failed: failed,
        ),
      );
    });
  }

  static const _disabledResult = DriveDiscoveryResult(
    status: DriveDiscoveryStatus.disabled,
    listed: 0,
    monitored: 0,
    invalid: 0,
    failed: 0,
  );

  static String _key(List<int> value) =>
      value.map((item) => item.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _decode(String value) => [
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16),
  ];
}
