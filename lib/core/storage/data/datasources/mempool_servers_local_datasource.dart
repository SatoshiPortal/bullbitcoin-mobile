part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [MempoolServers])
class MempoolServersLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$MempoolServersLocalDatasourceMixin {
  MempoolServersLocalDatasource(super.attachedDatabase);

  Future<void> store(MempoolServerRow row) {
    return into(mempoolServers).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<MempoolServerRow?> fetchByNetwork({
    required bool isLiquid,
    required bool isTestnet,
    required bool isCustom,
  }) {
    return attachedDatabase.managers.mempoolServers
        .filter((f) => f.isLiquid(isLiquid))
        .filter((f) => f.isTestnet(isTestnet))
        .filter((f) => f.isCustom(isCustom))
        .getSingleOrNull();
  }

  Future<int> trashCustomByNetwork({
    required bool isLiquid,
    required bool isTestnet,
  }) {
    return attachedDatabase.managers.mempoolServers
        .filter((f) => f.isLiquid(isLiquid))
        .filter((f) => f.isTestnet(isTestnet))
        .filter((f) => f.isCustom(true))
        .delete();
  }
}
