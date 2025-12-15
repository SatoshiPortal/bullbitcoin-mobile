import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:drift/drift.dart';

class ElectrumSettingsStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumSettingsStorageDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(ElectrumSettingsModel settings) async {
    try {
      final row = settings.toSqlite();
      await _sqlite.into(_sqlite.electrumSettings).insertOnConflictUpdate(row);

      log.fine(
        'Successfully stored/updated electrum settings: ${settings.network}',
      );
    } catch (e) {
      log.severe('Failed to store/update electrum settings: $e');
      rethrow;
    }
  }

  Future<List<ElectrumSettingsModel>> fetchAll() async {
    final rows = await _sqlite.managers.electrumSettings.get();

    final settings = rows
        .map((row) => ElectrumSettingsModel.fromSqlite(row))
        .toList();

    return settings;
  }

  Future<List<ElectrumSettingsModel>> fetchByEnvironment(
    ElectrumEnvironment environment,
  ) async {
    final rows = await _sqlite.managers.electrumSettings
        .filter(
          (f) =>
              f.network(
                environment.isTestnet
                    ? ElectrumServerNetwork.bitcoinTestnet
                    : ElectrumServerNetwork.bitcoinMainnet,
              ) |
              f.network(
                environment.isTestnet
                    ? ElectrumServerNetwork.liquidTestnet
                    : ElectrumServerNetwork.liquidMainnet,
              ),
        )
        .get();

    final settings = rows
        .map((row) => ElectrumSettingsModel.fromSqlite(row))
        .toList();

    return settings;
  }

  Future<ElectrumSettingsModel> fetchByNetwork(
    ElectrumServerNetwork network,
  ) async {
    final row = await _sqlite.managers.electrumSettings
        .filter((f) => f.network(network))
        .getSingle();

    final settings = ElectrumSettingsModel.fromSqlite(row);

    return settings;
  }
}
