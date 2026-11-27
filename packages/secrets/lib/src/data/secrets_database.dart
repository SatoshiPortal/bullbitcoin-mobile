import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'secrets_database.drift.dart';

class Wallets extends Table {
  @internal
  Wallets();

  TextColumn get id => text()();
  TextColumn get secretFingerprint => text().nullable()();
  TextColumn get masterFingerprint => text()();
  TextColumn get signer => text()();
  TextColumn get network => text()();
  TextColumn get xpub => text()();
  TextColumn get externalDescriptor => text()();
  TextColumn get internalDescriptor => text()();
  TextColumn get label => text().nullable()();
  TextColumn get birthday => text().nullable()();
  BoolColumn get isDefault => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class Derivations extends Table {
  @internal
  Derivations();

  TextColumn get parentFingerprint => text()();
  TextColumn get path => text()();
  TextColumn get application => text()();
  TextColumn get status => text()();
  TextColumn get alias => text().nullable()();

  @override
  Set<Column> get primaryKey => {parentFingerprint, path};
}

class Credentials extends Table {
  @internal
  Credentials();

  TextColumn get id => text()();
  TextColumn get scheme => text()();
  BlobColumn get salt => blob()();
  TextColumn get params => text()();
  BlobColumn get verifier => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccessViewRow')
class Views extends Table {
  @internal
  Views();

  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get backgroundEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get credentialId =>
      text().nullable().references(Credentials, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class ViewMembers extends Table {
  @internal
  ViewMembers();

  TextColumn get viewId =>
      text().references(Views, #id, onDelete: KeyAction.cascade)();
  TextColumn get member => text()();

  @override
  Set<Column> get primaryKey => {viewId, member};
}

@DataClassName('AccessStateRow')
class AccessState extends Table {
  @internal
  AccessState();

  IntColumn get singleton => integer()();
  IntColumn get failedAttempts => integer()();
  IntColumn get lockedUntil => integer().nullable()();
  TextColumn get importReceipt => text()();

  /// The view opened last, so the next opening starts there. A memory, never a
  /// right: it is read only after an authentication and only among the views
  /// that authentication opened.
  TextColumn get lastViewId => text().nullable()();

  @override
  Set<Column> get primaryKey => {singleton};

  @override
  List<String> get customConstraints => [
    'CHECK (singleton = 1)',
    'CHECK (failed_attempts >= 0)',
  ];
}

@DriftDatabase(
  tables: [Wallets, Derivations, Credentials, Views, ViewMembers, AccessState],
)
final class SecretsDatabase extends $SecretsDatabase {
  @internal
  SecretsDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      // Drift writes user_version outside onCreate. A restart between those
      // commits must keep the tables that already exist.
      for (final table in allTables) {
        await migrator.createTable(table);
      }
    }),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
