import 'package:drift/drift.dart';

@DataClassName('KeychainManifestEntryRow')
class KeychainManifestEntries extends Table {
  TextColumn get entryId => text()();
  TextColumn get parentFingerprint => text()();
  TextColumn get derivationKind => text()();
  TextColumn get derivationPath => text()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entryId};
}

@DataClassName('KeychainManifestWalletBindingRow')
class KeychainManifestWalletBindings extends Table {
  TextColumn get walletId => text()();
  TextColumn get entryId => text().customConstraint(
    'NOT NULL REFERENCES keychain_manifest_entries(entry_id)',
  )();
  TextColumn get childSeedFingerprint => text()();
  TextColumn get network => text()();
  TextColumn get scriptType => text()();
  TextColumn get provenance => text()();
  BoolColumn get seedPassphraseUsed => boolean().nullable()();
  TextColumn get descriptor => text().nullable()();
  TextColumn get label => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {walletId};
}

@DataClassName('KeychainManifestNostrKeyRow')
class KeychainManifestNostrKeys extends Table {
  TextColumn get entryId => text().customConstraint(
    'NOT NULL REFERENCES keychain_manifest_entries(entry_id)',
  )();
  TextColumn get publicKeyHex => text()();
  TextColumn get keyKind => text()();
  TextColumn get purpose => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entryId};
}
