import 'package:drift/drift.dart';

import 'order_swaps_database.drift.dart';
import 'order_swaps_table.dart';

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [OrderSwaps, LegacyImportReceipts])
final class OrderSwapsDatabase extends $OrderSwapsDatabase {
  static const schema = 1;

  OrderSwapsDatabase(super.executor);

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => transaction(() async {
      // The receipt table is created in the same transaction as all order
      // tables and indices. Drift can persist user_version after this commits.
      final created = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'legacy_import_receipts'",
      ).getSingleOrNull();
      if (created == null) await m.createAll();
    }),
  );
}
