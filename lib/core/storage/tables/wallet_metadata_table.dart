import 'package:drift/drift.dart';

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpubFingerprint => text()();
  BoolColumn get isEncryptedVaultTested => boolean()();
  BoolColumn get isPhysicalBackupTested => boolean()();
  IntColumn get latestEncryptedBackup => integer().nullable()();
  IntColumn get latestPhysicalBackup => integer().nullable()();
  TextColumn get xpub => text()();
  TextColumn get externalPublicDescriptor => text()();
  TextColumn get internalPublicDescriptor => text()();
  TextColumn get source => text()();
  BoolColumn get isDefault => boolean()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
