import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
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

  Future<Result<bool, RecoverBullCoreFailure>> execute() async {
    try {
      final result = await _ensureTorSessionUsecase.execute();
      if (result case Ok(:final value)) {
        try {
          await _recoverBullRepository.checkConnection(value.endpoint);
          return const Ok(true);
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
      if (result case Err(:final failure)) return Err(failure);
      return const Ok(false);
    } catch (error) {
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }
}
