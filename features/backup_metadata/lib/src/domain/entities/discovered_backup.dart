import 'package:backup_storage/backup_storage.dart' show BackupDestination;

import 'backup_content.dart';
import 'backup_inventory.dart';

final class DiscoveredBackup {
  final BackupGroup group;
  final BackupDestination destination;
  final DateTime? storedAt;
  final BackupContent content;

  /// The view the discovery ran in; apply refuses another one.
  final String scope;

  const DiscoveredBackup({
    required this.group,
    required this.destination,
    required this.storedAt,
    required this.content,
    required this.scope,
  });
}
