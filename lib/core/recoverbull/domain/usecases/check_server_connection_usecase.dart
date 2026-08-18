import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class CheckServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  CheckServerConnectionUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase,
  );

  /// `false` rather than a failure: this only answers "is the server
  /// reachable right now", and every caller retries on its own schedule.
  ///
  /// Every `await` stays inside the `try`. Returning the repository call as a
  /// future instead would chain it *outside* this block — an `async` function
  /// completes a returned future after leaving the `try`, so the throw would
  /// escape to the caller rather than become `false`.
  Future<bool> execute() async {
    try {
      final result = await _ensureTorSessionUsecase.execute();
      if (result case Ok(:final value)) {
        try {
          await _recoverBullRepository.checkConnection(value.endpoint);
          return true;
        } finally {
          // Without this the outer catch would turn a *successful* check into
          // `false` just because tearing the session down failed.
          try {
            await value.close();
          } catch (e, st) {
            log.warning(
              'closing the RecoverBull Tor session failed',
              error: e,
              trace: st,
            );
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
