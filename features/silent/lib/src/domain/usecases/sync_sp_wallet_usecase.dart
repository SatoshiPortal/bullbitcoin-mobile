import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:silent/src/domain/sp_scan_policy.dart';
import 'package:silent/src/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:silent/src/domain/usecases/scan_sp_wallet_usecase.dart';

/// The SP side of an automatic sync tick: resume the chain scan when the wallet
/// already had one in flight, or when [SpScanPolicy] says it is close enough to
/// the tip to do it without asking.
///
/// Never runs outside the foreground: bwk's scan takes the account lock, and a
/// backgrounded process can be frozen or killed mid-scan. A wallet with no
/// cursor, or one far enough behind that the scan would be long, is left for
/// the user to start by hand.
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

  Future<Result<void, SilentFailure>>? _inFlight;
  bool _inFlightResumeOnly = false;

  /// [resumeOnly] is the retry path: it picks up a scan the app already had in
  /// flight and never starts one from the policy, so a failed scan is retried
  /// without turning every tick into a fresh automatic scan.
  Future<Result<void, SilentFailure>> execute({bool resumeOnly = false}) {
    if (_inFlight case final active?) {
      // A full tick that arrives behind a resume-only one must not be dropped:
      // queue it, so the policy still gets its say this round.
      if (_inFlightResumeOnly && !resumeOnly) {
        return active.then((_) => execute());
      }
      return active;
    }
    _inFlightResumeOnly = resumeOnly;
    return _inFlight = _run(resumeOnly: resumeOnly)
        .whenComplete(() => _inFlight = null);
  }

  Future<Result<void, SilentFailure>> _run({required bool resumeOnly}) async {
    if (!_isForeground() || _isSpScanningUsecase.execute()) {
      return const Ok(null);
    }

    // Ok(null) when the feature gate is closed or the wallet is not set up.
    final SilentWallet wallet;
    switch (await _getSpWalletUsecase.execute()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final w):
        if (w == null) return const Ok(null);
        wallet = w;
    }

    // Awaited, not the cached value: the first tick can run before the keystore
    // read finished, and an automatic scan must honour a disabled setting.
    if (!await _getSpAutoScanUsecase.read()) return const Ok(null);

    // The decision is judged against this revision; the repository rechecks it
    // at launch, so a stop, clear, or session recycle in between wins.
    final admission = (revision: _repository.scanRevision);
    if (wallet.hasPendingScan) {
      // A pending scan the user stopped is theirs to restart, not ours.
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
