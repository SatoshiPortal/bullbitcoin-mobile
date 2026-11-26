import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/ports/sp_scan_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// The single Dart entry point to the Rust scan. Callers are limited to
/// `SpCubit.scan()` (the Scan button handler), `CreateSpWalletUsecase` (seeding
/// the cursor at the tip when the user picked a new wallet at setup) and
/// `SyncSpWalletUsecase` (the sync tick, which scans only when `SpScanPolicy`
/// allows it). Do NOT call it from a lifecycle hook, timer, route observer or
/// background service directly: the policy lives in `SyncSpWalletUsecase` and
/// the audit script depends on that staying the only automatic route.
class ScanSpWalletUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final SpScanPort _repository;

  ScanSpWalletUsecase({
    required this._getSpFeatureGateUsecase,
    required this._repository,
  });

  /// `startHeight` overrides where the scan begins (null resumes from the last
  /// scanned position); used by the first-scan start chooser.
  ///
  /// [automatic] marks a scan the app decided on its own. Its admission is
  /// rechecked in the repository against the state at launch, and an automatic
  /// scan that is refused returns `Ok(null)` rather than a failure.
  @useResult
  Future<Result<void, SilentFailure>> execute({
    int? startHeight,
    SpAutomaticScanAdmission? automatic,
  }) async {
    if (!await _getSpFeatureGateUsecase.execute()) {
      return const Err(SilentUnsupportedNetwork());
    }
    return _repository.scanOnce(startHeight: startHeight, automatic: automatic);
  }
}
