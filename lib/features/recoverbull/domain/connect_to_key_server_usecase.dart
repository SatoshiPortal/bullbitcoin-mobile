import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Reaches the key server, retrying on a backoff.
///
/// Reaching it is an onion-service lookup — a descriptor fetch, then a
/// rendezvous — which routinely needs more than one try just after a cold
/// bootstrap. The schedule and the attempt accounting live here so the screen
/// only renders what an attempt reports.
class ConnectToKeyServerUsecase {
  /// How many times the server is contacted before giving up. Published
  /// because the screen shows the attempt out of this total.
  static const int maxAttempts = 3;

  final CheckServerConnectionUsecase _checkServerConnectionUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  /// Injected so a test does not have to spend the backoff in real time.
  final Future<void> Function(Duration) _wait;

  ConnectToKeyServerUsecase(
    this._checkServerConnectionUsecase,
    this._ensureTorSessionUsecase, {
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  /// [onAttempt] fires before each call with a 1-based attempt number, so the
  /// caller can show which attempt is in flight rather than which one failed.
  ///
  /// The first attempt, including Tor route acquisition, is immediate. Delaying
  /// it would add a second to every start, including the common case where the
  /// server answers at once.
  Future<Result<bool, RecoverBullCoreFailure>> execute({
    required void Function(int attempt) onAttempt,
  }) async {
    // This route is owned by this execution only: no route or HTTP client is
    // retained after the finally block completes.
    RecoverBullTorRoute? route;
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (attempt > 1) await _wait(Duration(seconds: attempt - 1));
        onAttempt(attempt);
        if (attempt == 1) {
          final ensured = await _ensureTorSessionUsecase.execute();
          switch (ensured) {
            case Ok(:final value):
              route = value;
            case Err(:final failure):
              return Err(failure);
          }
        }
        final result = await _checkServerConnectionUsecase.execute(
          route: route,
        );
        switch (result) {
          case Ok(value: true):
            return const Ok(true);
          case Ok():
            break;
          case Err(:final failure)
              when failure is ExternalTorProxyUnavailableFailure:
            return Err(failure);
          case Err():
            break;
        }
      }
      return const Ok(false);
    } finally {
      try {
        if (route != null) await route.close();
      } catch (e, st) {
        // Closing is cleanup only and must not replace the connection result.
        log.warning(
          'closing the RecoverBull Tor session failed',
          error: e,
          trace: st,
        );
      }
    }
  }
}
