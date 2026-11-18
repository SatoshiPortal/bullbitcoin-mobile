import 'package:drift/drift.dart';

/// Internal ledger database. The host owns path, lifecycle and migration fencing.
/// Explicit SQL keeps the three private tables out of the public Drift row API.
final class PaymentDatabase extends GeneratedDatabase {
  static const _schema = {
    'payments': '''CREATE TABLE payments (
      network TEXT NOT NULL, hash TEXT NOT NULL, request TEXT NOT NULL,
      amount_msat INTEGER NOT NULL CHECK(amount_msat > 0),
      revision INTEGER NOT NULL, review_id INTEGER NOT NULL,
      attempt_count INTEGER NOT NULL, active_ordinal INTEGER,
      stage TEXT NOT NULL, PRIMARY KEY(network, hash))''',
    'payment_reviews': '''CREATE TABLE payment_reviews (
      network TEXT NOT NULL, hash TEXT NOT NULL, id INTEGER NOT NULL,
      policy TEXT NOT NULL, sources TEXT NOT NULL,
      PRIMARY KEY(network, hash, id),
      FOREIGN KEY(network, hash) REFERENCES payments(network, hash))''',
    'payment_attempts': '''CREATE TABLE payment_attempts (
      network TEXT NOT NULL, hash TEXT NOT NULL, ordinal INTEGER NOT NULL,
      operation_id TEXT NOT NULL UNIQUE, review_id INTEGER NOT NULL,
      wallet TEXT NOT NULL, rail TEXT NOT NULL, ceiling INTEGER NOT NULL,
      stage TEXT NOT NULL, backend TEXT, receipt TEXT,
      PRIMARY KEY(network, hash, ordinal),
      FOREIGN KEY(network, hash, review_id) REFERENCES payment_reviews(network, hash, id))''',
  };

  PaymentDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final existing = await customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      ).get();
      if (existing.isNotEmpty) {
        throw const FormatException('Invalid payment ledger schema');
      }
      for (final sql in _schema.values) {
        await customStatement(sql);
      }
    },
    onUpgrade: (_, _, _) async {
      throw const FormatException('Unsupported payment ledger schema version');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      String normalize(String sql) =>
          sql.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
      for (final entry in _schema.entries) {
        final tables = await customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [
            const Variable<String>('table'),
            Variable<String>(entry.key),
          ],
        ).get();
        if (tables.length != 1 ||
            normalize(tables.single.read<String>('sql')) !=
                normalize(entry.value)) {
          throw const FormatException('Invalid payment ledger schema');
        }
      }
      if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
        throw const FormatException('Invalid payment ledger schema');
      }
    },
  );
}
