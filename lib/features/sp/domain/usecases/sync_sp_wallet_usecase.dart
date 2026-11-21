import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';

/// The SP side of an automatic sync tick: resume the chain scan when
/// [SpScanPolicy] says the wallet is close enough to the tip to do it without
/// asking. A wallet with no cursor, or one far enough behind that the scan
/// would be long, is left for the user to start by hand.
///
/// Registered as a singleton so the in-flight guard serializes ticks: the tip
/// watcher and the sync coordinator drive this independently, and the
/// `isScanning` check below cannot separate them on its own (two awaits elapse
/// before `scanOnce` sets the flag, so both would pass it).
class SyncSpWalletUsecase {
  final SpAccountRepository _repository;
  final GetSpWalletUsecase _getSpWalletUsecase;
  final IsSpScanningUsecase _isSpScanningUsecase;
  final ScanSpWalletUsecase _scanSpWalletUsecase;
  final GetSpAutoScanUsecase _getSpAutoScanUsecase;
  final bool Function() _isForeground;

  SyncSpWalletUsecase({
    required this._repository,
    required this._getSpWalletUsecase,
    required this._isSpScanningUsecase,
    required this._scanSpWalletUsecase,
    required this._getSpAutoScanUsecase,
    required this._isForeground,
  });

  Future<Result<void, SpFailure>>? _inFlight;
  bool _inFlightResumeOnly = false;

  Future<Result<void, SpFailure>> execute({bool resumeOnly = false}) {
    if (_inFlight case final active?) {
      if (_inFlightResumeOnly && !resumeOnly) {
        return active.then((_) => execute());
      }
      return active;
    }
    _inFlightResumeOnly = resumeOnly;
    return _inFlight = _run(resumeOnly: resumeOnly)
        .whenComplete(() => _inFlight = null);
  }

  Future<Result<void, SpFailure>> _run({required bool resumeOnly}) async {
    if (!_isForeground() || _isSpScanningUsecase.execute()) {
      return const Ok(null);
    }

    // Ok(null) when the feature gate is closed or the wallet is not set up.
    final SpWallet wallet;
    switch (await _getSpWalletUsecase.execute()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final w):
        if (w == null) return const Ok(null);
        wallet = w;
    }

    final autoScanEnabled = await _getSpAutoScanUsecase.read();
    if (!autoScanEnabled) return const Ok(null);
    final admission = (
      revision: wallet.scanRevision,
      isAllowed: () => _isForeground() && _getSpAutoScanUsecase.execute(),
    );
    if (wallet.hasPendingScan) {
      if (wallet.isPendingScanPaused) return const Ok(null);
      return _scanSpWalletUsecase.execute(automatic: admission);
    }
    if (resumeOnly) return const Ok(null);

    final policy = SpScanPolicy(
      lastScannedHeight: wallet.lastScannedHeight,
      chainTip: _repository.chainTip(),
    );
    if (policy.trigger != SpScanTrigger.automatic) return const Ok(null);

    return _scanSpWalletUsecase.execute(automatic: admission);
  }
}
