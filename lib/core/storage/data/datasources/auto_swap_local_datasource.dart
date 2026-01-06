part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [AutoSwap])
class AutoSwapLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$AutoSwapLocalDatasourceMixin {
  AutoSwapLocalDatasource(super.attachedDatabase);

  Future<void> store(AutoSwapRow row) {
    return into(autoSwap).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<AutoSwapRow> fetchById(int id) {
    return (select(autoSwap)..where((tbl) => tbl.id.equals(id))).getSingle();
  }
}
