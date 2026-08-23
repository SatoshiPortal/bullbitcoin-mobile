import 'package:drift/drift.dart';

@DataClassName('KeychainManifestEntryRow')
class KeychainManifestEntries extends Table {
  TextColumn get entryId => text()();
  TextColumn get parentFingerprint => text()();
  TextColumn get bip85DerivationPath => text()();
  TextColumn get reservationId => text()();
  TextColumn get entryType => text()();
  TextColumn get ownerFeature => text()();
  IntColumn get bip85Application => integer()();
  IntColumn get bip85Index => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entryId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {parentFingerprint, bip85DerivationPath},
  ];
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
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entryId};
}
