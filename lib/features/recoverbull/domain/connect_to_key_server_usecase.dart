import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
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

  /// Injected so a test does not have to spend the backoff in real time.
  final Future<void> Function(Duration) _wait;

  ConnectToKeyServerUsecase(
    this._checkServerConnectionUsecase, {
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  /// [onAttempt] fires before each call with a 1-based attempt number, so the
  /// caller can show which attempt is in flight rather than which one failed.
  ///
  /// The first attempt is immediate. Tor readiness is already awaited before
  /// this runs, so delaying it only added a second to every start, including
  /// the common case where the server answers at once.
  Future<Result<bool, RecoverBullCoreFailure>> execute({
    required void Function(int attempt) onAttempt,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) await _wait(Duration(seconds: attempt - 1));
      onAttempt(attempt);
      final result = await _checkServerConnectionUsecase.execute();
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
  }
}
