import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';

class DriftMempoolSettingsRepository implements MempoolSettingsRepository {
  final MempoolSettingsStorageDatasource _datasource;

  DriftMempoolSettingsRepository({
    required MempoolSettingsStorageDatasource
        mempoolSettingsStorageDatasource,
  }) : _datasource = mempoolSettingsStorageDatasource;

  @override
  Future<void> save(MempoolSettings settings) {
    final model = MempoolSettingsModel.fromEntity(settings);
    return _datasource.store(model);
  }

  @override
  Future<MempoolSettings> fetchByNetwork(MempoolServerNetwork network) async {
    final model = await _datasource.fetchByNetwork(network);
    return model.toEntity();
  }
}
