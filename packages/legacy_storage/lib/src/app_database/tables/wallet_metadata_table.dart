import 'package:drift/drift.dart';

enum Signer {
  local,
  remote,
  none;

  static Signer fromName(String name) {
    return Signer.values.firstWhere((source) => source.name == name);
  }
}

enum SignerDevice {
  bitbox02,
  coldcardQ,
  coldcardMk4,
  jade,
  keystone,
  krux,
  ledgerNanoSPlus,
  ledgerNanoX,
  ledgerFlex,
  ledgerStax,
  passport,
  seedsigner,
  specter,
}

@DataClassName('WalletMetadataRow')
class WalletMetadatas extends Table {
  TextColumn get id => text()();
  TextColumn get network => text().withDefault(const Constant('unresolved'))();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpubFingerprint => text()();
  BoolColumn get isEncryptedVaultTested => boolean()();
  BoolColumn get isPhysicalBackupTested => boolean()();
  IntColumn get latestEncryptedBackup => integer().nullable()();
  IntColumn get latestPhysicalBackup => integer().nullable()();
  TextColumn get xpub => text()();
  TextColumn get externalPublicDescriptor => text()();
  TextColumn get internalPublicDescriptor => text()();
  TextColumn get signer => text()();
  TextColumn get signerDevice => textEnum<SignerDevice>().nullable()();
  BoolColumn get isDefault => boolean()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
