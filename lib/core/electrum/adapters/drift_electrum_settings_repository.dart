import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DriftElectrumSettingsRepository implements ElectrumSettingsRepository {
  final ElectrumSettingsStorageDatasource _datasource;

  DriftElectrumSettingsRepository({
    required ElectrumSettingsStorageDatasource
    electrumSettingsStorageDatasource,
  }) : _datasource = electrumSettingsStorageDatasource;

  @override
  Future<Result<void, ElectrumFailure>> save(ElectrumSettings settings) async {
    try {
      final model = ElectrumSettingsModel.fromEntity(settings);
      await _datasource.store(model);
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save electrum settings',
        error: e,
        trace: st,
      );
      return Err(ElectrumSaveFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchAll() async {
    try {
      final models = await _datasource.fetchAll();
      return Ok(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch all electrum settings',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<ElectrumSettings, ElectrumFailure>> fetchByNetwork(
    ElectrumServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchByNetwork(network);
      return Ok(model.toEntity());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch electrum settings by network',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchByEnvironment(
    ElectrumEnvironment environment,
  ) async {
    try {
      final models = await _datasource.fetchByEnvironment(environment);
      return Ok(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch electrum settings by environment',
        error: e,
        trace: st,
      );
      return Err(ElectrumLoadFailure(e.toString()));
    }
  }
}
