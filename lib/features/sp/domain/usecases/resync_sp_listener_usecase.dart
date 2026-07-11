import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';

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

  Future<void> execute() async {
    if (!_repository.hasSession) return;
    if (_repository.isScanningCached) return;
    await _repository.restartElectrum();
  }
}
