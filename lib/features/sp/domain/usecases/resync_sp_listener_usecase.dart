import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Restarts the taproot electrum listener in place when the app returns to
/// foreground. Android kills a backgrounded app's socket, so a coin received
/// while away is otherwise missed until a full restart. The in-place restart
/// (stop + start, keeping the session and its streams alive) reconnects +
/// re-subscribes + re-syncs, which surfaces the missed coin.
///
/// No-op when no session is live (the listener only runs then) or while a scan
/// is running (the restart would block on the scan's inner lock; the live stores
/// are already current then).
class ResyncSpListenerUsecase {
  final SpAccountRepository _repository;

  ResyncSpListenerUsecase({required this._repository});

  Future<Result<void, SpFailure>> execute() async {
    if (!_repository.hasSession) return const Ok(null);
    if (_repository.isScanningCached) return const Ok(null);
    try {
      await _repository.restartElectrum();
      return const Ok(null);
    } catch (e) {
      return Err(SpUnexpected('SP listener resync failed: $e'));
    }
  }
}
