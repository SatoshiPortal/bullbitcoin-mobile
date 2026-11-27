/// Composition contracts for the foreground flow.
library;

export 'src/backup_metadata_feature.dart'
    show BackupMetadataFeature, BackupMetadataTrigger;
export 'src/backup_metadata_locator.dart' show BackupMetadataLocator;
export 'src/data/backup_metadata_store.dart'
    show BackupMetadataKey, BackupMetadataStore;
export 'src/data/metadata_backup_inventory.dart' show MetadataBackupInventory;
export 'src/data/bip138_backup_metadata_codec.dart'
    show Bip138BackupMetadataCodec;
export 'src/data/metadata_backup_labels.dart' show MetadataBackupLabels;
export 'src/data/metadata_backup_secrets.dart' show MetadataBackupSecrets;
export 'src/domain/ports/backup_inventory_port.dart' show BackupInventoryPort;
export 'src/domain/ports/backup_labels_port.dart' show BackupLabelsPort;
export 'src/domain/ports/backup_secrets_port.dart'
    show BackupSecretsPort, BackupSessionRef, SecretsRestoreReport;
export 'src/domain/repositories/backup_metadata_codec.dart'
    show BackupMetadataCodec, PreparedBackup;
