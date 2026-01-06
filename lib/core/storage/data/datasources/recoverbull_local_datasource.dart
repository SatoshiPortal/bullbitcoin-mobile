part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Recoverbull])
class RecoverbullLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$RecoverbullLocalDatasourceMixin {
  RecoverbullLocalDatasource(super.attachedDatabase);

  Future<void> store(RecoverbullRow row) {
    return into(recoverbull).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<RecoverbullRow> fetchById(int id) {
    return attachedDatabase.managers.recoverbull
        .filter((f) => f.id(id))
        .getSingle();
  }

  Future<void> patchPermission({
    required int id,
    required bool isPermissionGranted,
  }) {
    return attachedDatabase.managers.recoverbull.update(
      (f) => f(id: Value(id), isPermissionGranted: Value(isPermissionGranted)),
    );
  }
}
