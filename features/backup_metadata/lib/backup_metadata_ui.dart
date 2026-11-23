/// Presentation API for the host router and its adapters.
library;

export 'generated/l10n/backup_metadata_localizations.dart';
export 'src/ui/backup_metadata_localizations_delegate.dart';
export 'src/ui/backup_metadata_views.dart';
export 'src/ui/backup_metadata_restore_views.dart';

abstract final class BackupMetadataRoutes {
  static const settings = 'backupMetadata';
}
