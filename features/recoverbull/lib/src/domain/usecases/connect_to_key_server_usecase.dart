import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import 'check_server_connection_usecase.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';

/// Reaches the key server once; the screen owns the decision to retry.
class ConnectToKeyServerUsecase {
  final LogSink log;
  final CheckServerConnectionUsecase _checkServerConnectionUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  ConnectToKeyServerUsecase({
    required CheckServerConnectionUsecase check,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    required this.log,
  }) : _checkServerConnectionUsecase = check,
       _ensureTorSessionUsecase = ensureTor;

  Future<Result<bool, RecoverBullFailure>> execute({
    void Function(int)? onAttempt,
    RecoverBullTorRoute? route,
  }) async {
    final ownsRoute = route == null;
    final elapsed = Stopwatch()..start();
    try {
      onAttempt?.call(1);
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
      final Result<bool, RecoverBullFailure> result = switch (checked) {
        Ok(value: true) => const Ok(true),
        Ok() => const Err(KeyServerUnavailableFailure()),
        Err(:final failure) => Err(failure),
      };
      switch (result) {
        case Ok():
          log.fine(
            'recoverbull.server_check.succeeded duration_ms=${elapsed.elapsedMilliseconds}',
          );
        case Err(:final failure):
          final cause = switch (failure) {
            KeyServerUnavailableFailure(:final cause, :final httpStatus) =>
              '${cause.name}${httpStatus == null ? '' : ' http=$httpStatus'}',
            _ => failure.supportCause ?? failure.runtimeType.toString(),
          };
          log.warning(
            'recoverbull.server_check.failed duration_ms=${elapsed.elapsedMilliseconds} cause=$cause',
          );
      }
      return result;
    } finally {
      if (ownsRoute && route != null) {
        try {
          await route.close();
        } on Exception catch (error) {
          log.warning(
            'recoverbull.tor.session.close.failed error_type=${error.runtimeType}',
          );
        }
      }
    }
  }
}
