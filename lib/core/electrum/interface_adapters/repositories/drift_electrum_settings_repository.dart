import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';

class DriftElectrumSettingsRepository implements ElectrumSettingsRepository {
  final ElectrumSettingsStorageDatasource _datasource;

  DriftElectrumSettingsRepository({
    required ElectrumSettingsStorageDatasource
    electrumSettingsStorageDatasource,
  }) : _datasource = electrumSettingsStorageDatasource;

  @override
  Future<void> save(ElectrumSettings settings) {
    final model = ElectrumSettingsModel.fromEntity(settings);
    return _datasource.store(model);
  }

  @override
  Future<List<ElectrumSettings>> fetchAll() {
    return _datasource.fetchAll().then(
      (models) => models.map((m) => m.toEntity()).toList(),
    );
  }

  @override
  Future<ElectrumSettings> fetchByNetwork(ElectrumServerNetwork network) async {
    final model = await _datasource.fetchByNetwork(network);
    return model.toEntity();
  }

  @override
  Future<List<ElectrumSettings>> fetchByEnvironment(
    ElectrumEnvironment environment,
  ) async {
    final model = await _datasource.fetchByEnvironment(environment);
    return model.map((m) => m.toEntity()).toList();
  }
}
