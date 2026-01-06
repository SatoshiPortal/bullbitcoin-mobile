part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [ElectrumSettings])
class ElectrumSettingsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$ElectrumSettingsLocalDatasourceMixin {
  ElectrumSettingsLocalDatasource(super.attachedDatabase);

  Future<void> store(ElectrumSettingsRow row) {
    return into(electrumSettings).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<List<ElectrumSettingsRow>> fetchAll() {
    return attachedDatabase.managers.electrumSettings.get();
  }

  Future<List<ElectrumSettingsRow>> fetchByNetworks(
    List<ElectrumServerNetwork> networks,
  ) {
    return attachedDatabase.managers.electrumSettings
        .filter((f) => f.network.isIn(networks))
        .get();
  }

  Future<ElectrumSettingsRow> fetchByNetwork(ElectrumServerNetwork network) {
    return attachedDatabase.managers.electrumSettings
        .filter((f) => f.network(network))
        .getSingle();
  }
}
