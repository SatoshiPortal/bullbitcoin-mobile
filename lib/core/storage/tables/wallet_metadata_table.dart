import 'package:drift/drift.dart';

@DataClassName('WalletMetadataModel')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpubFingerprint => text()();
  BoolColumn get isBitcoin => boolean()();
  BoolColumn get isLiquid => boolean()();
  BoolColumn get isMainnet => boolean()();
  BoolColumn get isTestnet => boolean()();
  BoolColumn get isEncryptedVaultTested => boolean()();
  BoolColumn get isPhysicalBackupTested => boolean()();
  IntColumn get latestEncryptedBackup => integer().nullable()();
  IntColumn get latestPhysicalBackup => integer().nullable()();
  TextColumn get scriptType => text()();
  TextColumn get xpub => text()();
  TextColumn get externalPublicDescriptor => text()();
  TextColumn get internalPublicDescriptor => text()();
  TextColumn get source => text()();
  BoolColumn get isDefault => boolean()();
  TextColumn get label => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
