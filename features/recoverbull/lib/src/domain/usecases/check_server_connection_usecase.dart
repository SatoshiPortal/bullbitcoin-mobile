import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:primitives/primitives.dart';

class CheckServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  CheckServerConnectionUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase,
  );

  /// Checks the server through [route].
  ///
  /// When [route] is omitted, this use case acquires and owns a route for the
  /// duration of this call, and closes it before returning. When [route] is
  /// provided, the caller retains ownership: this use case uses its endpoint
  /// but never acquires or closes it.
  Future<Result<bool, RecoverBullCoreFailure>> execute({
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
        await _recoverBullRepository.checkConnection(routeToCheck);
        return const Ok(true);
      } finally {
        if (acquired) {
          // Without this the outer catch would turn a *successful* check into
          // `false` just because tearing the session down failed.
          try {
            await routeToCheck.close();
          } catch (e, st) {
            log.warning(
              'closing the RecoverBull Tor session failed',
              error: e,
              trace: st,
            );
          }
        }
      }
    } catch (error) {
      return const Err(KeyServerUnavailableFailure());
    }
  }
}
