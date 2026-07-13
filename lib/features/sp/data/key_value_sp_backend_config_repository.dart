import 'dart:convert';

import 'dart:developer' as developer;

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_backend_config_mapper.dart';
import 'package:bb_mobile/features/sp/data/models/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart';

class KeyValueSpBackendConfigRepository implements SpBackendConfigRepository {
  static const String _storageKey = 'sp_backend_config';

  final KeyValueStorageDatasource<String> _storage;

  // bwk connection-test free functions, injectable so `testBackend` can be
  // unit-tested without a real backend.
  final Future<void> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;

  KeyValueSpBackendConfigRepository({
    required this._storage,
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) : _testBlindbit = testBlindbit ?? testBlindbitUrl,
       _testElectrum = testElectrum ?? testElectrumUrl;

  @override
  Future<void> save(SpBackendConfig config) => _storage.saveValue(
    key: _storageKey,
    value: jsonEncode(SpBackendConfigMapper.toModel(config).toJson()),
  );

  @override
  Future<Result<SpBackendConfig?, SpFailure>> fetch() async {
    final jsonString = await _storage.getValue(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const Ok(null);
    }
    // Boundary: corrupt JSON (FormatException) or an unknown network name
    // (ArgumentError from SpNetwork.values.byName) become a typed failure
    // instead of an unhandled throw.
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Ok(
        SpBackendConfigMapper.toEntity(SpBackendConfigModel.fromJson(json)),
      );
    } catch (e) {
      return Err(SpConfigInvalid('SP backend config parse failed: $e'));
    }
  }

  @override
  Future<void> delete() => _storage.deleteValue(_storageKey);

  @override
  Future<Result<void, SpFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async {
    try {
      switch (kind) {
        case SpBackendKind.blindbit:
          await _testBlindbit(url: url);
        case SpBackendKind.electrum:
          await _testElectrum(url: url);
      }
      return const Ok(null);
    } catch (e) {
      developer.log(
        'SP backend test failed ($kind, $url): $e',
        name: 'SP',
      );
      log.warning('SP backend test failed ($kind, $url)', error: e);
      return Err(SpBackendUnreachable('SP backend test failed ($url): $e'));
    }
  }

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() async {
    final defaults = await getRegtestDefaults();
    if (!defaults.isOk) {
      return Err(SpBackendUnreachable(defaults.error));
    }
    return Ok(
      SpBackendDefaults(
        blindbitUrl: defaults.blindbitUrl,
        electrumUrl: defaults.electrumUrl,
      ),
    );
  }
}
