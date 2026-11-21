import 'package:electrum/src/domain/electrum_environment.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/data/models/electrum_settings_model.dart';
import 'package:electrum/src/storage/electrum_dao.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class ElectrumSettingsStorageDatasource {
  final ElectrumDao _sqlite;

  ElectrumSettingsStorageDatasource({required GeneratedDatabase sqlite})
    : _sqlite = ElectrumDao(sqlite);

  Future<void> store(ElectrumSettingsModel settings) async {
    try {
      final row = settings.toSqlite();
      await _sqlite.into(_sqlite.electrumSettings).insertOnConflictUpdate(row);

      log.fine(
        'Successfully stored/updated electrum settings: ${settings.network}',
      );
    } catch (e) {
      log.severe(
        message: 'Failed to store/update electrum settings',
        error: e.runtimeType,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }

  Future<List<ElectrumSettingsModel>> fetchAll() async {
    final rows = await _sqlite.settingsRows.get();

    final settings = rows
        .map((row) => ElectrumSettingsModel.fromSqlite(row))
        .toList();

    return settings;
  }

  Future<List<ElectrumSettingsModel>> fetchByEnvironment(
    ElectrumEnvironment environment,
  ) async {
    final rows = await _sqlite.settingsRows
        .filter(
          (f) =>
              f.network(
                ElectrumServerNetwork.fromEnvironment(
                  environment: environment,
                  isLiquid: false,
                ),
              ) |
              f.network(
                ElectrumServerNetwork.fromEnvironment(
                  environment: environment,
                  isLiquid: true,
                ),
              ),
        )
        .get();

    final settings = rows
        .map((row) => ElectrumSettingsModel.fromSqlite(row))
        .toList();

    return settings;
  }

  Future<ElectrumSettingsModel?> fetchByNetwork(
    ElectrumServerNetwork network,
  ) async {
    final row = await _sqlite.settingsRows
        .filter((f) => f.network(network))
        .getSingleOrNull();
    return row == null ? null : ElectrumSettingsModel.fromSqlite(row);
  }
}
