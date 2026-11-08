import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Reaches the key server once.
///
/// An attempt is bounded by the session's connect budget and the probe's deadline. Whether to try again, on the same route or on a new circuit, is the user's call on the connecting screen.
class ConnectToKeyServerUsecase {
  final CheckServerConnectionUsecase _checkServerConnectionUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  ConnectToKeyServerUsecase(
    this._checkServerConnectionUsecase,
    this._ensureTorSessionUsecase,
  );

  Future<Result<void, RecoverBullCoreFailure>> execute({
    RecoverBullTorRoute? route,
  }) async {
    // A supplied route remains owned by its flow; standalone callers retain the existing acquire-and-close behavior.
    final ownsRoute = route == null;
    final startedAt = DateTime.now();
    try {
      if (route == null) {
        final ensured = await _ensureTorSessionUsecase.execute();
        switch (ensured) {
          case Ok(:final value):
            route = value;
          case Err(:final failure):
            return Err(failure);
        }
      }
      final checked = await _checkServerConnectionUsecase.execute(route: route);
      final result = switch (checked) {
        Ok(value: true) => const Ok<void, RecoverBullCoreFailure>(null),
        Ok() => const Err<void, RecoverBullCoreFailure>(
          KeyServerUnavailableFailure(),
        ),
        Err(:final failure) => Err<void, RecoverBullCoreFailure>(failure),
      };
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      switch (result) {
        case Ok():
          log.fine('Key server attempt succeeded in ${seconds}s');
          return result;
        case Err(:final failure):
          final reason = switch (failure) {
            KeyServerUnavailableFailure(:final cause, :final httpStatus) =>
              httpStatus == null ? cause.name : '${cause.name} $httpStatus',
            _ => failure.runtimeType.toString(),
          };
          log.warning('Key server attempt failed in ${seconds}s: $reason');
          return Err(failure);
      }
    } finally {
      try {
        if (ownsRoute && route != null) await route.close();
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
