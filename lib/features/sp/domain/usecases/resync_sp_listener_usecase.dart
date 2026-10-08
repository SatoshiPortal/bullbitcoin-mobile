import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Restarts the electrum listener in place after a header initial-sync
/// failure. The in-place restart (stop + start, keeping the session and its
/// streams alive) reconnects + re-subscribes + re-syncs. It holds the account
/// lock across a blocking connect, so it only runs when the connection is
/// known to be broken, never on a routine refresh.
///
/// No-op when no session is live (the listener only runs then) or while a scan
/// is running (the restart would block on the scan's inner lock; the live stores
/// are already current then).
class ResyncSpListenerUsecase {
  final SpAccountRepository _repository;
  final SpScanControlPort _scanControl;

  ResyncSpListenerUsecase({
    required this._repository,
    required this._scanControl,
  });

  Future<Result<void, SpFailure>> execute() async {
    if (!_repository.hasSession) return const Ok(null);
    if (_scanControl.isScanningCached) return const Ok(null);
    return _scanControl.restartElectrum();
  }
}
