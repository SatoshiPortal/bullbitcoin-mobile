import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart' show BackupDestination;

import 'backup_inventory.dart';

import 'package:labels/backup.dart';

final class DiscoveredBackup {
  final BackupGroup group;
  final BackupDestination destination;
  final DateTime? storedAt;
  final LabelsSnapshot snapshot;

  const DiscoveredBackup({
    required this.group,
    required this.destination,
    required this.storedAt,
    required this.snapshot,
  });
}
