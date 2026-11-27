import 'package:intl/intl.dart';

import '../../generated/l10n/backup_metadata_localizations.dart';
import '../domain/entities/backup_summary.dart';

/// The entry's status line: off, or on with the last durable backup.
String backupSummaryLabel(
  BackupMetadataLocalizations l10n,
  BackupSummary summary,
  String locale,
) {
  final at = summary.lastDurableBackup;
  if (!summary.enabled) return l10n.off;
  if (at == null) return l10n.statusOn;
  return l10n.recentStatus(
    DateFormat.yMMMd(locale).add_jm().format(at.toLocal()),
  );
}
