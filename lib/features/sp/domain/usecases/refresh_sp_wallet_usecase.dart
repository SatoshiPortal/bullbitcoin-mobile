import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';

/// Reads a fresh SP wallet snapshot. When a session is live it returns that
/// session's current snapshot; when none exists `EnsureSpSession` establishes
/// one via `createFromMnemonic`. It never disposes a live session: the scanner
/// updates the live stores in place, so the snapshot is already current, and
/// tearing the session down here would kill a running background scan.
class RefreshSpWalletUsecase {
  final SpAccountRepository _repository;
  final GetSpWalletUsecase _getSpWalletUsecase;

  RefreshSpWalletUsecase({
    required this._repository,
    required this._getSpWalletUsecase,
  });

  /// Whether a scan is running (tracked in Dart, no FFI).
  bool get isScanning => _repository.isScanningCached;

  /// `Ok(null)` when SP is not set up (gated / revoked); `Ok(wallet)` with the
  /// current snapshot otherwise. `Err` when establishing/reading the session
  /// failed (e.g. a dispose still holds the inner lock): the caller keeps its
  /// state intact and retries later.
  Future<Result<SpWallet?, SpFailure>> execute() async {
    try {
      return Ok(await _getSpWalletUsecase.execute());
    } catch (e) {
      return Err(SpUnexpected('SP refresh failed: $e'));
    }
  }
}
