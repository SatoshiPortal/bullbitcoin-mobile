/// Composition contracts for the dormant foreground and headless flows.
library;

export 'src/backup_metadata_task.dart' show runBackupMetadataTask;
export 'src/data/metadata_backup_inventory.dart' show MetadataBackupInventory;
export 'src/data/metadata_backup_labels.dart' show MetadataBackupLabels;
export 'src/data/metadata_backup_readiness.dart' show MetadataBackupReadiness;
export 'src/domain/ports/backup_inventory_port.dart' show BackupInventoryPort;
export 'src/domain/ports/backup_labels_port.dart' show BackupLabelsPort;
export 'src/domain/ports/backup_readiness_port.dart' show BackupReadinessPort;
export 'src/domain/repositories/backup_metadata_codec.dart'
    show BackupMetadataCodec, PreparedBackup;
