import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/data/mappers/sp_backend_config_mapper.dart';
import 'package:bb_mobile/features/sp/data/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

class KeyValueSpBackendConfigRepository implements SpBackendConfigRepository {
  static const String _storageKey = 'sp_backend_config';

  final KeyValueStorageDatasource<String> _storage;

  // Cached view of "is set up" for the GoRouter redirect, which cannot await.
  bool _isSetUp = false;

  KeyValueSpBackendConfigRepository({required this._storage});

  @override
  bool get isSetUpNow => _isSetUp;

  @override
  void setIsSetUpNow({required bool isSetUp}) => _isSetUp = isSetUp;

  @override
  Future<Result<void, SpFailure>> save(SpBackendConfig config) async {
    try {
      await _storage.saveValue(
        key: _storageKey,
        value: jsonEncode(SpBackendConfigMapper.toModel(config).toJson()),
      );
      return const Ok(null);
    } catch (e) {
      return Err(SpUnexpected('SP backend config save failed: $e'));
    }
  }

  @override
  Future<Result<SpBackendConfig?, SpFailure>> fetch() async {
    final String? jsonString;
    try {
      jsonString = await _storage.getValue(_storageKey);
    } catch (e) {
      // A locked keystore must not throw past the repository boundary.
      return Err(SpUnexpected('SP backend config read failed: $e'));
    }
    if (jsonString == null || jsonString.isEmpty) {
      return const Ok(null);
    }
    // Corrupt JSON (FormatException) or an unknown network name (ArgumentError
    // from SpNetwork.values.byName) become a typed failure, kept apart from a
    // read failure so a locked keystore is not reported as a bad config.
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Ok(
        SpBackendConfigMapper.toEntity(SpBackendConfigModel.fromJson(json)),
      );
    } catch (e) {
      // Logged here because the callers that fold this to "no config" cannot.
      log.warning('SP backend config parse failed: $e');
      return Err(SpConfigInvalid('SP backend config parse failed: $e'));
    }
  }

  @override
  Future<Result<void, SpFailure>> delete() async {
    try {
      await _storage.deleteValue(_storageKey);
      return const Ok(null);
    } catch (e) {
      return Err(SpUnexpected('SP backend config delete failed: $e'));
    }
  }
}
