import 'package:backup_storage/backup_storage.dart' show BackupDestination;

import '../ports/backup_secrets_port.dart';
import 'backup_content.dart';
import 'backup_inventory.dart';

final class DiscoveredBackup {
  final BackupGroup group;
  final BackupDestination destination;
  final DateTime? storedAt;
  final BackupContent content;

  /// The session the discovery ran in; preview and apply refuse a backup
  /// once it is no longer current, even if the same view was reopened.
  final BackupSessionRef scope;

  const DiscoveredBackup({
    required this.group,
    required this.destination,
    required this.storedAt,
    required this.content,
    required this.scope,
  });
}
