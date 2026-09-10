import 'dart:async';

import './check_server_connection_usecase.dart';
import '../recoverbull_tor_route.dart';
import '../recoverbull_failure.dart';
import './ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

typedef RecoverBullTimeout =
    Future<T> Function<T>(Future<T> future, Duration timeout);

Future<T> _defaultTimeout<T>(Future<T> future, Duration timeout) =>
    future.timeout(timeout);

/// Reaches the key server, retrying on a backoff.
///
/// Reaching it is an onion-service lookup — a descriptor fetch, then a
/// rendezvous — which routinely needs more than one try just after a cold
/// bootstrap. The schedule and the attempt accounting live here so the screen
/// only renders what an attempt reports.
class ConnectToKeyServerUsecase {
  final LogSink log;

  /// The 30-second envelope covers server health checks and their retry
  /// backoffs, starting once a Tor route is available. It deliberately excludes
  /// Tor bootstrap: that phase measured 37.2 seconds on a Pixel 6a and 50
  /// seconds on a Samsung, and is already tracked separately as tor_bootstrap.
  /// Health checks measured 0.6 to 29.98 seconds, so this envelope avoids
  /// adding their deadlines and retry backoff together (about 93 seconds).
  static const Duration connectionBudget = Duration(seconds: 30);
  static const Duration healthCheckTimeout = Duration(seconds: 30);

  /// How many times the server is contacted before giving up. Published
  /// because the screen shows the attempt out of this total.
  static const int maxAttempts = 3;

  final CheckServerConnectionUsecase _checkServerConnectionUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  /// Injected so a test does not have to spend the backoff in real time.
  final Future<void> Function(Duration) _wait;
  final Duration Function()? _elapsed;
  final Future<Result<bool, RecoverBullFailure>> Function({
    required RecoverBullTorRoute route,
    required Duration timeout,
  })?
  _checkWithTimeout;
  final RecoverBullTimeout _timeout;

  ConnectToKeyServerUsecase({
    required CheckServerConnectionUsecase check,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    required this.log,
    Future<void> Function(Duration)? wait,
    Duration Function()? elapsed,
    Duration budget = connectionBudget,
    int maxAttempts = ConnectToKeyServerUsecase.maxAttempts,
    RecoverBullTimeout? timeout,
    Future<Result<bool, RecoverBullFailure>> Function({
      required RecoverBullTorRoute route,
      required Duration timeout,
    })?
    checkWithTimeout,
  }) : _checkServerConnectionUsecase = check,
       _ensureTorSessionUsecase = ensureTor,
       _wait = wait ?? Future<void>.delayed,
       // ignore: prefer_initializing_formals
       _elapsed = elapsed,
       // The public parameter keeps the injectable seam readable at call sites.
       // ignore: prefer_initializing_formals
       _budget = budget,
       // ignore: prefer_initializing_formals
       _maxAttempts = maxAttempts,
       _timeout = timeout ?? _defaultTimeout,
       // ignore: prefer_initializing_formals
       _checkWithTimeout = checkWithTimeout;

  final Duration _budget;
  final int _maxAttempts;

  /// [onAttempt] fires before each call with a 1-based attempt number, so the
  /// caller can show which attempt is in flight rather than which one failed.
  ///
  /// The first attempt, including Tor route acquisition, is immediate. Delaying
  /// it would add a second to every start, including the common case where the
  /// server answers at once.
  Future<Result<bool, RecoverBullFailure>> execute({
    required void Function(int attempt) onAttempt,
    RecoverBullTorRoute? route,
  }) async {
    final ownsRoute = route == null;
    final stopwatch = Stopwatch()..start();
    Duration elapsed() => _elapsed?.call() ?? stopwatch.elapsed;
    var budgetStarted = route != null;
    var budgetStartedAt = budgetStarted ? elapsed() : Duration.zero;
    var budgetLogged = false;

    Duration remaining() {
      if (!budgetStarted) return _budget;
      final left = _budget - (elapsed() - budgetStartedAt);
      return left.isNegative ? Duration.zero : left;
    }

    bool budgetExhausted() {
      if (!budgetLogged) {
        budgetLogged = true;
        log.warning('recoverbull.server_check.budget_exhausted');
      }
      return true;
    }

    try {
      for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
        var left = remaining();
        if (left <= Duration.zero) {
          budgetExhausted();
          break;
        }
        if (attempt > 1) {
          final backoff = Duration(seconds: attempt - 1);
          await _wait(backoff < left ? backoff : left);
          left = remaining();
          if (left <= Duration.zero) {
            budgetExhausted();
            break;
          }
        }
        onAttempt(attempt);
        if (attempt == 1 && route == null) {
          final ensured = await _ensureTorSessionUsecase.execute();
          switch (ensured) {
            case Ok(:final value):
              route = value;
              budgetStarted = true;
              budgetStartedAt = elapsed();
            case Err(:final failure):
              return Err(failure);
          }
        }
        final routeToCheck = route;
        if (routeToCheck == null || (left = remaining()) <= Duration.zero) {
          budgetExhausted();
          break;
        }
        late final Result<bool, RecoverBullFailure> result;
        try {
          final timeout = left < healthCheckTimeout ? left : healthCheckTimeout;
          if (_checkWithTimeout case final checkWithTimeout?) {
            result = await checkWithTimeout(
              route: routeToCheck,
              timeout: timeout,
            );
          } else {
            result = await _timeout(
              _checkServerConnectionUsecase.execute(route: routeToCheck),
              timeout,
            );
          }
        } on TimeoutException {
          budgetExhausted();
          break;
        }
        switch (result) {
          case Ok(value: true):
            return const Ok(true);
          case Ok():
            break;
          case Err(:final failure)
              when failure is ExternalTorProxyUnavailableFailure:
            return Err(failure);
          case Err(:final failure)
              when failure is KeyServerHealthCheckTimeoutFailure:
            return Err(failure);
          case Err(:final failure) when failure is KeyServerBusyFailure:
            return Err(failure);
          case Err(:final failure)
              when failure is RecoverBullTemporarilyUnavailableFailure:
            return Err(failure);
          case Err():
            break;
        }
      }
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
