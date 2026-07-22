import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// USER-TRIGGERED ONLY. This is the single Dart entry point to the Rust scan.
/// Only `SpCubit.scan()` (the Scan button handler) may invoke this use case.
/// Do NOT call from lifecycle hooks, timers, route observers, or background
/// services; the no-auto-scan invariant depends on it.
class ScanSpWalletUsecase {
  final SpAccountRepository _repository;

  ScanSpWalletUsecase({required this._repository});

  /// `startHeight` overrides where the scan begins (null resumes from the last
  /// scanned position); used by the first-scan start chooser.
  @useResult
  Future<Result<void, SpFailure>> execute({int? startHeight}) =>
      _repository.scanOnce(startHeight: startHeight);
}
