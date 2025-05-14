import 'package:drift/drift.dart';

enum NewWalletSource {
  mnemonic,
  xpub,
  descriptors,
  coldcard;

  static NewWalletSource fromName(String name) {
    return NewWalletSource.values.firstWhere((source) => source.name == name);
  }
}

@DataClassName('V5MigrateWalletMetadataRow')
class V5MigrateWalletMetadatas extends Table {
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
  TextColumn get source => textEnum<NewWalletSource>()();
  BoolColumn get isDefault => boolean()();
  TextColumn get label => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
