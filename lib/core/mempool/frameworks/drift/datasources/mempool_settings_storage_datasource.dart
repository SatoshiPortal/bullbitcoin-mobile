import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class MempoolSettingsStorageDatasource {
  final SqliteDatabase _sqlite;

  const MempoolSettingsStorageDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(MempoolSettingsModel settings) async {
    try {
      final row = settings.toSqlite();
      await _sqlite.into(_sqlite.mempoolSettings).insertOnConflictUpdate(row);

      log.fine(
        'Successfully stored/updated mempool settings: ${settings.network}',
      );
    } catch (e) {
      log.severe('Failed to store/update mempool settings: $e');
      rethrow;
    }
  }

  Future<MempoolSettingsModel> fetchByNetwork(
    MempoolServerNetwork network,
  ) async {
    final networkString = network.networkString;

    final row = await _sqlite.managers.mempoolSettings
        .filter((f) => f.network.equals(networkString))
        .getSingleOrNull();

    if (row == null) {
      throw Exception(
        'No mempool settings found for network: $network. '
        'Database may not be properly seeded.',
      );
    }

    final settings = MempoolSettingsModel.fromSqlite(row);

    return settings;
  }
}
