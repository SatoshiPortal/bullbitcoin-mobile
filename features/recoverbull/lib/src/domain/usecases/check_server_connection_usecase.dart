import '../repositories/recoverbull_repository.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import './ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class CheckServerConnectionUsecase {
  final LogSink log;
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  CheckServerConnectionUsecase({
    required RecoverBullRepository repository,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    required this.log,
  }) : _recoverBullRepository = repository,
       _ensureTorSessionUsecase = ensureTor;

  /// Checks the server through [route].
  ///
  /// When [route] is omitted, this use case acquires and owns a route for the
  /// duration of this call, and closes it before returning. When [route] is
  /// provided, the caller retains ownership: this use case uses its endpoint
  /// but never acquires or closes it.
  Future<Result<bool, RecoverBullFailure>> execute({
    RecoverBullTorRoute? route,
  }) async {
    try {
      final acquired = route == null;
      if (route == null) {
        final result = await _ensureTorSessionUsecase.execute();
        switch (result) {
          case Ok(:final value):
            route = value;
          case Err(:final failure):
            return Err(failure);
        }
      }
      final routeToCheck = route;
      try {
        final connection = await _recoverBullRepository.checkConnection(
          routeToCheck,
        );
        return connection.map((_) => true);
      } finally {
        if (acquired) {
          // Without this the outer catch would turn a *successful* check into
          // `false` just because tearing the session down failed.
          try {
            await routeToCheck.close();
          } catch (e, _) {
            log.warning(
              'recoverbull.tor.session.close.failed error_type=${e.runtimeType}',
            );
          }
        }
      }
    } catch (error) {
      return const Err(KeyServerUnavailableFailure());
    }
  }
}
