import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/drift.dart';

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get network => textEnum<Network>()();
  BoolColumn get isEncryptedVaultTested => boolean()();
  BoolColumn get isPhysicalBackupTested => boolean()();
  IntColumn get latestEncryptedBackup => integer().nullable()();
  IntColumn get latestPhysicalBackup => integer().nullable()();
  TextColumn get publicDescriptor => text()();
  BoolColumn get isDefault => boolean()();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get hideOnHome => boolean().nullable()();
  BoolColumn get autoSweepEnabled => boolean().nullable()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  TextColumn get provenance =>
      text().withDefault(const Constant('watchOnly'))();
  BoolColumn get seedPassphraseUsed => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
