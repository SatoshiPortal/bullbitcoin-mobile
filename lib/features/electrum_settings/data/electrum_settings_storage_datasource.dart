import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';

class ElectrumSettingsStorageDatasource {
  final SqliteDatabase _sqlite;

  const ElectrumSettingsStorageDatasource({required this._sqlite});

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
