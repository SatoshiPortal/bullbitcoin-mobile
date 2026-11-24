import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_defaults.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Reaches the SP backends without a live session: the standalone connection
/// test the setup form runs, and the defaults the regtest infra reports.
///
/// Kept apart from `SpBackendConfigRepository`, which only persists what the
/// user settled on.
abstract interface class SpBackendProbePort {
  /// Probe only the Blindbit tip, without opening an account or scanning.
  @useResult
  Future<Result<void, SilentFailure>> blindbitTip(String url);

  /// Test one backend URL by actually connecting. `Ok(null)` when it connects;
  /// `Err` with [SilentBackendUnreachable] carrying the raw reason as `logMessage`
  /// (never shown to the user) otherwise. This is a try/catch boundary.
  @useResult
  Future<Result<void, SilentFailure>> testBackend(
    SpBackendKind kind,
    String url,
  );

  /// Resolve the regtest backend defaults from the running regtest infra over
  /// FFI. Awaits the fetch off the UI isolate; `Err` with [SilentBackendUnreachable]
  /// when the infra is unreachable.
  @useResult
  Future<Result<SpBackendDefaults, SilentFailure>> fetchRegtestDefaults();
}
