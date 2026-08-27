import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DriftMempoolSettingsRepository implements MempoolSettingsRepository {
  final MempoolSettingsStorageDatasource _datasource;

  DriftMempoolSettingsRepository({
    required MempoolSettingsStorageDatasource mempoolSettingsStorageDatasource,
  }) : _datasource = mempoolSettingsStorageDatasource;

  @override
  Future<Result<void, MempoolFailure>> save(MempoolSettings settings) async {
    try {
      final model = MempoolSettingsModel.fromEntity(settings);
      await _datasource.store(model);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save mempool settings',
        error: e,
        trace: st,
      );
      return Err(MempoolSaveFailure(e.toString()));
    }
  }

  @override
  Future<Result<MempoolSettings, MempoolFailure>> fetchByNetwork(
    MempoolServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchByNetwork(network);
      return Ok(model.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch mempool settings',
        error: e,
        trace: st,
      );
      return Err(MempoolLoadFailure(e.toString()));
    }
  }
}
