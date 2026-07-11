import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

class RevokeSpWalletUsecase {
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;

  RevokeSpWalletUsecase({
    required this._repository,
    required this._configRepository,
  });

  /// Revoke the SP wallet.
  ///
  /// The on-disk teardown (sentinel-before-dispose, dispose, recursive delete
  /// with partial-delete recovery) lives in `repository.revokeOnDisk`; this
  /// use case only orchestrates the surrounding steps:
  ///   1. `revokeOnDisk` writes the `.revoked` sentinel, disposes the live
  ///      session, then deletes the account dir. It rethrows on a delete
  ///      failure, having already emitted `SpSetupChanged` so observers drop
  ///      the SP card; the config delete and final notify below are then
  ///      skipped since the sentinel already blocks any load.
  ///   2. Delete the persisted backend config so the wallet cannot be
  ///      reconstructed. A delete failure must not abort the revoke, so log and
  ///      proceed.
  ///   3. Emit `SpSetupChanged` so observers (the wallet home) re-evaluate and
  ///      drop the SP card.
  ///
  /// The whole flow runs under `beginTeardown`/`endTeardown` so a live cubit's
  /// self-heal cannot establish a competing session mid-revoke.
  ///
  /// Idempotent: safe to re-run when already revoked or the dir is already gone.
  ///
  /// Returns `Err` when the on-disk delete failed; the `.revoked` sentinel is
  /// already written and observers already dropped the SP card, so the caller
  /// only needs to surface a retry prompt.
  Future<Result<void, SpFailure>> execute() async {
    _repository.beginTeardown();
    try {
      await _repository.revokeOnDisk();

      try {
        await _configRepository.delete();
      } catch (e) {
        log.warning(
          'RevokeSpWalletUsecase: config delete failed, proceeding: $e',
        );
      }

      _repository.notifySetupChanged();
      return const Ok(null);
    } catch (e) {
      return Err(SpUnexpected('SP revoke failed: $e'));
    } finally {
      _repository.endTeardown();
    }
  }
}
