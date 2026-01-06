part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [MempoolSettings])
class MempoolSettingsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$MempoolSettingsLocalDatasourceMixin {
  MempoolSettingsLocalDatasource(super.attachedDatabase);

  Future<void> store(MempoolSettingsRow row) {
    return into(mempoolSettings).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<MempoolSettingsRow?> fetchByNetwork(String network) {
    return attachedDatabase.managers.mempoolSettings
        .filter((f) => f.network.equals(network))
        .getSingleOrNull();
  }
}
