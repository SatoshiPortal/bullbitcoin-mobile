import 'backup_settings.dart';

enum BackupAlertKind { unexplainedActivity, lockout }

/// The presentation contract deliberately carries no backup identifier or count.
final class BackupAlert {
  final int acknowledgement;
  final BackupAlertKind kind;

  const BackupAlert(this.acknowledgement, this.kind);
}

final class BackupMonitoring {
  final bool unknown;
  final List<BackupAlert> alerts;

  BackupMonitoring({required this.unknown, required List<BackupAlert> alerts})
    : alerts = List.unmodifiable(alerts);
}

/// Internal fencing token, never exported to presentation consumers.
final class MonitoringCheck {
  final BackupSettings settings;
  final int revision;
  final Set<String> digests;

  MonitoringCheck(this.settings, this.revision, Set<String> digests)
    : digests = Set.unmodifiable(digests);
}

final class OwnBackupOperation {
  final int id;
  final BackupSettings settings;

  const OwnBackupOperation(this.id, this.settings);
}
