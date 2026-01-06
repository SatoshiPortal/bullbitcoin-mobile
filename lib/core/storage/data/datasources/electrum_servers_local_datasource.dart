part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [ElectrumServers])
class ElectrumServersLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$ElectrumServersLocalDatasourceMixin {
  ElectrumServersLocalDatasource(super.attachedDatabase);

  Future<void> store(ElectrumServerRow row) {
    return into(electrumServers).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<void> storeBatch(List<ElectrumServerRow> rows) {
    return batch((batch) {
      for (final row in rows) {
        batch.insert(
          electrumServers,
          row.toCompanion(true),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<ElectrumServerRow?> fetchByUrl(String url) {
    return attachedDatabase.managers.electrumServers
        .filter((f) => f.url.equals(url))
        .getSingleOrNull();
  }

  Future<List<ElectrumServerRow>> fetchAll({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  }) {
    var query = attachedDatabase.managers.electrumServers.filter(
      (f) => const Constant(true),
    );

    if (isLiquid != null) {
      query = query.filter((f) => f.isLiquid(isLiquid));
    }
    if (isTestnet != null) {
      query = query.filter((f) => f.isTestnet(isTestnet));
    }
    if (isCustom != null) {
      query = query.filter((f) => f.isCustom(isCustom));
    }

    return query.get();
  }

  Future<List<ElectrumServerRow>> fetchByNetwork({
    required bool isLiquid,
    required bool isTestnet,
    required bool isCustom,
  }) {
    return attachedDatabase.managers.electrumServers
        .filter(
          (f) =>
              f.isLiquid(isLiquid) &
              f.isTestnet(isTestnet) &
              f.isCustom(isCustom),
        )
        .get();
  }

  Future<int> trashByUrl(String url) {
    return attachedDatabase.managers.electrumServers
        .filter((f) => f.url.equals(url))
        .delete();
  }
}
