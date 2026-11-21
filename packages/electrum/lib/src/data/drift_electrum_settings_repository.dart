import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/electrum_failure.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:electrum/src/domain/electrum_environment.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/data/electrum_settings_storage_datasource.dart';
import 'package:electrum/src/data/models/electrum_settings_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

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
    } on Exception {
      log.warning('Failed to save electrum settings');
      return const Err(ElectrumSaveFailure());
    }
  }

  @override
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchAll() async {
    try {
      final models = await _datasource.fetchAll();
      return Ok(models.map((m) => m.toEntity()).toList());
    } on Exception {
      log.warning('Failed to fetch all electrum settings');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<ElectrumSettings, ElectrumFailure>> fetchByNetwork(
    ElectrumServerNetwork network,
  ) async {
    try {
      final model = await _datasource.fetchByNetwork(network);
      if (model == null) return const Err(ElectrumLoadFailure());
      return Ok(model.toEntity());
    } on Exception {
      log.warning('Failed to fetch electrum settings by network');
      return const Err(ElectrumLoadFailure());
    }
  }

  @override
  Future<Result<List<ElectrumSettings>, ElectrumFailure>> fetchByEnvironment(
    ElectrumEnvironment environment,
  ) async {
    try {
      final models = await _datasource.fetchByEnvironment(environment);
      return Ok(models.map((m) => m.toEntity()).toList());
    } on Exception {
      log.warning('Failed to fetch electrum settings by environment');
      return const Err(ElectrumLoadFailure());
    }
  }
}
