import 'package:drift/drift.dart';

/// Schema checks that make a migration step safe to run again over a database
/// it has already changed, in whole or in part. See "Database schema migration
/// support" in AGENTS.md.
extension MigrationGuards on Migrator {
  Future<bool> hasTable(String table) async {
    final rows = await database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable<String>(table)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<bool> hasRows(String table) async {
    if (!await hasTable(table)) return false;
    final rows = await database
        .customSelect('SELECT 1 FROM "$table" LIMIT 1')
        .get();
    return rows.isNotEmpty;
  }

  Future<bool> hasColumn(String table, String column) async {
    final rows = await database
        .customSelect(
          'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
          variables: [Variable<String>(table), Variable<String>(column)],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// The column's declared DEFAULT as SQL text, or null when it has none or
  /// does not exist.
  Future<String?> columnDefault(String table, String column) async {
    final rows = await database
        .customSelect(
          'SELECT dflt_value FROM pragma_table_info(?) WHERE name = ?',
          variables: [Variable<String>(table), Variable<String>(column)],
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.single.readNullable<String>('dflt_value');
  }

  Future<void> addColumnIfMissing(
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if (await hasColumn(table.actualTableName, column.name)) return;
    await addColumn(table, column);
  }

  Future<void> dropColumnIfPresent(TableInfo table, String column) async {
    if (!await hasColumn(table.actualTableName, column)) return;
    await dropColumn(table, column);
  }
}
