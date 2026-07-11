import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Persists the [SpBackendConfig] so the live session can be reconstructed via
/// `createFromMnemonic` on every load, instead of relying on `SpAccount.load`
/// reading a config file the FFI create path never writes.
abstract interface class SpBackendConfigRepository {
  Future<void> save(SpBackendConfig config);

  /// Read the stored config. `Ok(null)` when nothing is stored; `Err` with
  /// [SpConfigInvalid] when the stored JSON is corrupt or names an unknown
  /// network. This is a try/catch boundary; callers never see a raw parse
  /// exception.
  @useResult
  Future<Result<SpBackendConfig?, SpFailure>> fetch();

  Future<void> delete();

  /// Test one backend URL by actually connecting (standalone, no live SP
  /// session). `Ok(null)` when it connects; `Err` with [SpBackendUnreachable]
  /// carrying the raw reason as `logMessage` (never shown to the user)
  /// otherwise. This is a try/catch boundary.
  @useResult
  Future<Result<void, SpFailure>> testBackend(BackendKind kind, String url);

  /// Resolve the regtest backend defaults from the running regtest infra
  /// (FFI). Returns a failed [SpBackendDefaults] when the infra is unreachable.
  SpBackendDefaults fetchRegtestDefaults();
}
