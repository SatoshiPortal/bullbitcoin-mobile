import './check_server_connection_usecase.dart';
import '../recoverbull_tor_route.dart';
import '../recoverbull_failure.dart';
import './ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Reaches the key server, retrying on a backoff.
///
/// Reaching it is an onion-service lookup — a descriptor fetch, then a
/// rendezvous — which routinely needs more than one try just after a cold
/// bootstrap. The schedule and the attempt accounting live here so the screen
/// only renders what an attempt reports.
class ConnectToKeyServerUsecase {
  final LogSink log;

  /// How many times the server is contacted before giving up. Published
  /// because the screen shows the attempt out of this total.
  ///
  /// Attempts reuse one route and carry no app-side deadline: each is bounded
  /// by Tor's own onion connect timeout. Arti keeps building the first
  /// rendezvous circuit after a request is abandoned, so an app deadline
  /// shorter than Tor's measurably gave up just before the circuit completed
  /// (Snowflake: 4/6 successes, median 93 s, against 5/5 and 48 s without it).
  static const int maxAttempts = 3;

  final CheckServerConnectionUsecase _checkServerConnectionUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  /// Injected so a test does not have to spend the backoff in real time.
  final Future<void> Function(Duration) _wait;
  final int _maxAttempts;

  ConnectToKeyServerUsecase({
    required CheckServerConnectionUsecase check,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    required this.log,
    Future<void> Function(Duration)? wait,
    int maxAttempts = ConnectToKeyServerUsecase.maxAttempts,
  }) : _checkServerConnectionUsecase = check,
       _ensureTorSessionUsecase = ensureTor,
       _wait = wait ?? Future<void>.delayed,
       // The public parameter keeps the injectable seam readable at call sites.
       // ignore: prefer_initializing_formals
       _maxAttempts = maxAttempts;

  /// [onAttempt] fires before each call with a 1-based attempt number, so the
  /// caller can show which attempt is in flight rather than which one failed.
  ///
  /// The first attempt, including Tor route acquisition, is immediate. Delaying
  /// it would add a second to every start, including the common case where the
  /// server answers at once. Later attempts back off 1 then 2 seconds.
  Future<Result<bool, RecoverBullFailure>> execute({
    required void Function(int attempt) onAttempt,
    RecoverBullTorRoute? route,
  }) async {
    final ownsRoute = route == null;
    RecoverBullFailure? lastTimeout;
    try {
      for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
        if (attempt > 1) await _wait(Duration(seconds: attempt - 1));
        onAttempt(attempt);
        if (route == null) {
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
            lastTimeout = null;
          case Err(:final failure)
              when failure is ExternalTorProxyUnavailableFailure:
            return Err(failure);
          case Err(:final failure)
              when failure is KeyServerHealthCheckTimeoutFailure:
            lastTimeout = failure;
          case Err(:final failure) when failure is KeyServerBusyFailure:
            return Err(failure);
          case Err(:final failure)
              when failure is RecoverBullTemporarilyUnavailableFailure:
            return Err(failure);
          case Err():
            lastTimeout = null;
        }
      }
      if (lastTimeout case final timeout?) return Err(timeout);
      return const Ok(false);
    } finally {
      try {
        if (ownsRoute && route != null) await route.close();
      } catch (e, _) {
        // Closing is cleanup only and must not replace the connection result.
        log.warning(
          'recoverbull.tor.session.close.failed error_type=${e.runtimeType}',
        );
      }
    }
  }
}
