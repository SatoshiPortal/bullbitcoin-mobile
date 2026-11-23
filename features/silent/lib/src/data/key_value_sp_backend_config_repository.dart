import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';

import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/data/mappers/sp_backend_config_mapper.dart';
import 'package:silent/src/data/sp_backend_config_model.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/silent_failure.dart';

class KeyValueSpBackendConfigRepository implements SpBackendConfigRepository {
  final SilentPaymentKeychain _storage;

  // Cached view of "is set up" for the GoRouter redirect, which cannot await.
  bool _isSetUp = false;

  KeyValueSpBackendConfigRepository({required this._storage});

  @override
  bool get isSetUpNow => _isSetUp;

  @override
  void setIsSetUpNow({required bool isSetUp}) => _isSetUp = isSetUp;

  @override
  Future<Result<void, SilentFailure>> save(SpBackendConfig config) async {
    try {
      final result = await _storage.writeBackend(
        jsonEncode(SpBackendConfigMapper.toModel(config).toJson()),
      );
      if (result case Err(:final failure)) {
        return Err(
          SilentUnexpected(
            'SP backend config save failed: ${failure.logMessage}',
          ),
        );
      }
      return const Ok(null);
    } catch (e) {
      return Err(SilentUnexpected('SP backend config save failed: $e'));
    }
  }

  @override
  Future<Result<SpBackendConfig?, SilentFailure>> fetch() async {
    final String? jsonString;
    try {
      switch (await _storage.readBackend()) {
        case Ok(:final value):
          jsonString = value;
        case Err(:final failure):
          return Err(
            SilentUnexpected(
              'SP backend config read failed: ${failure.logMessage}',
            ),
          );
      }
    } catch (e) {
      // A locked keystore must not throw past the repository boundary.
      return Err(SilentUnexpected('SP backend config read failed: $e'));
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
      return Err(SilentConfigInvalid('SP backend config parse failed: $e'));
    }
  }

  @override
  Future<Result<void, SilentFailure>> delete() async {
    try {
      final result = await _storage.deleteBackend();
      if (result case Err(:final failure)) {
        return Err(
          SilentUnexpected(
            'SP backend config delete failed: ${failure.logMessage}',
          ),
        );
      }
      return const Ok(null);
    } catch (e) {
      return Err(SilentUnexpected('SP backend config delete failed: $e'));
    }
  }
}
