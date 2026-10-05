import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// The single Dart entry point to the Rust scan. Callers are limited to
/// `SpCubit.scan()` (the Scan button handler), `CreateSpWalletUsecase` (seeding
/// the cursor at the tip when the user picked a new wallet at setup) and
/// `SyncSpWalletUsecase` (the sync tick, which scans only when `SpScanPolicy`
/// allows it). Do NOT call it from a lifecycle hook, timer, route observer or
/// background service directly: the policy lives in `SyncSpWalletUsecase` and
/// the audit script depends on that staying the only automatic route.
class ScanSpWalletUsecase {
  final SpScanPort _repository;

  ScanSpWalletUsecase({required this._repository});

  /// `startHeight` overrides where the scan begins (null resumes from the last
  /// scanned position); used by the first-scan start chooser.
  @useResult
  Future<Result<void, SpFailure>> execute({int? startHeight}) =>
      _repository.scanOnce(startHeight: startHeight);
}
