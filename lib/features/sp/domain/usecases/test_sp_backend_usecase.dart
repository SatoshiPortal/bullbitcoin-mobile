import 'package:bb_mobile/features/sp/domain/entities/backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Result of testing one backend URL: ok, or a human-readable error.
enum SpConnTest { untested, testing, ok, failed }

/// Validates a blindbit / electrum URL by actually connecting (standalone, no
/// live SP session). Orchestration only: the connect + try/catch lives in the
/// repository. Returns null when the URL connects, or the [SpFailure] otherwise
/// (its `logMessage` carries the raw reason, never shown to the user).
class TestSpBackendUsecase {
  final SpBackendConfigRepository _configRepository;

  TestSpBackendUsecase({required this._configRepository});


  Future<SpFailure?> test(BackendKind kind, String url) async {
    final result = await _configRepository.testBackend(kind, url);
    return result.fold((_) => null, (failure) => failure);
  }
}
