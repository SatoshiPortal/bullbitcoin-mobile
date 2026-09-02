import 'package:bull_logger/bull_logger.dart';

import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../entities/encrypted_vault.dart';
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
  final RecoverBullAttemptMonitoringStore store;
  final LogSink? log;

  const DiscoverDriveBackupsUsecase({
    required this.drive,
    required this.store,
    this.log,
  });

  Future<DriveDiscoveryResult> execute() async {
    try {
      return await _execute();
    } catch (_) {
      log?.warning('recoverbull.drive.discovery.failed');
      return const DriveDiscoveryResult(
        status: DriveDiscoveryStatus.failed,
        listed: 0,
        monitored: 0,
        invalid: 0,
        failed: 1,
      );
    }
  }

  Future<DriveDiscoveryResult> _execute() async {
    if (!(await store.state()).attemptMonitoringEnabled) {
      return const DriveDiscoveryResult(
        status: DriveDiscoveryStatus.disabled,
        listed: 0,
        monitored: 0,
        invalid: 0,
        failed: 0,
      );
    }
    return drive.withDiscoverySession((session) async {
      if (session == null) {
        return const DriveDiscoveryResult(
          status: DriveDiscoveryStatus.unauthenticated,
          listed: 0,
          monitored: 0,
          invalid: 0,
          failed: 0,
        );
      }
      final account = session.account;
      final List<RecoverBullDriveFile> files;
      try {
        files = await session.files();
      } catch (_) {
        log?.warning('recoverbull.drive.discovery.failed');
        return const DriveDiscoveryResult(
          status: DriveDiscoveryStatus.failed,
          listed: 0,
          monitored: 0,
          invalid: 0,
          failed: 1,
        );
      }
      if (files.isEmpty) {
        final applied = await store.reconcileDriveBackups(account, const []);
        if (!applied) return _disabledResult;
        return const DriveDiscoveryResult(
          status: DriveDiscoveryStatus.empty,
          listed: 0,
          monitored: 0,
          invalid: 0,
          failed: 0,
        );
      }

      final cache = await store.driveCache(account);
      final monitored = await store.monitoredBackups();
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
        final String content;
        try {
          content = await session.content(file.id);
        } catch (_) {
          failed++;
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
          continue;
        }
        try {
          final vault = EncryptedVault(file: content);
          observations.add(
            DriveBackupObservation(
              fileId: file.id,
              digest: store.digestFor(_decode(vault.id)),
              createdAt: file.createdTime,
              modifiedAt: file.modifiedTime,
            ),
          );
        } catch (_) {
          invalid++;
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
      final applied = await store.reconcileDriveBackups(account, observations);
      if (!applied) return _disabledResult;
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
      return DriveDiscoveryResult(
        status: status,
        listed: files.length,
        monitored: {for (final item in observations) item.digestKey}.length,
        invalid: invalid,
        failed: failed,
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
