import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

class RevokeSpWalletUsecase {
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final SpSessionGuard _guard;

  RevokeSpWalletUsecase({
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._guard,
  });

  /// Revoke the SP wallet.
  ///
  /// The order matters and is the reason this lives in a use case rather than
  /// behind one repository call:
  ///   1. Write the `.revoked` sentinel BEFORE any teardown, so a self-heal
  ///      racing the teardown sees a revoked dir and refuses to reload it.
  ///   2. Dispose the live session so the sqlite handle is released before the
  ///      delete. A dispose timeout must NOT abort the revoke (that would leave
  ///      the wallet undeletable), so it is logged and the revoke proceeds.
  ///   3. Delete the backups first, then the account dir. Sweeping backups
  ///      first means a failure here still leaves the dir and its sentinel in
  ///      place, so the wallet stays unloadable and a retry is safe. Deleting
  ///      the dir first would strand a backup with no sentinel anywhere, which
  ///      the next session establish would adopt as a live wallet.
  ///   4. Delete the persisted backend config so the wallet cannot be
  ///      reconstructed. A delete failure must not abort the revoke.
  ///   5. Emit `SpSetupChanged` so observers (the wallet home) re-evaluate and
  ///      drop the SP card.
  ///
  /// The whole flow runs under `beginTeardown`/`endTeardown` so a live cubit's
  /// self-heal cannot establish a competing session mid-revoke, and under
  /// [SpSessionGuard] so a backend-config save rebuilding that same session
  /// cannot interleave with it.
  ///
  /// Idempotent: safe to re-run when already revoked or the dir is already gone.
  ///
  /// Returns `Err` when the on-disk delete failed; the `.revoked` sentinel is
  /// already written and observers already dropped the SP card, so the caller
  /// only needs to surface a retry prompt.
  Future<Result<void, SpFailure>> execute() => _guard.exclusive(() async {
    _repository.beginTeardown();
    try {
      final revoked = await _revokeOnDisk();
      // The sentinel is on disk now, so the wallet is unloadable even if the
      // delete failed.
      _configRepository.setIsSetUpNow(isSetUp: false);
      if (revoked case Err(:final failure)) return Err(failure);

      if (await _configRepository.delete() case Err(:final failure)) {
        log.warning(
          'RevokeSpWalletUsecase: config delete failed, proceeding: '
          '${failure.logMessage}',
        );
      }

      _repository.notifySetupChanged();
      return const Ok(null);
    } catch (e) {
      return Err(SpUnexpected('SP revoke failed: $e'));
    } finally {
      _repository.endTeardown();
    }
  });

  Future<Result<void, SpFailure>> _revokeOnDisk() async {
    final bool accountDirExists;
    switch (await _files.accountDirExists()) {
      case Ok(:final value):
        accountDirExists = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (accountDirExists) {
      if (await _files.writeRevokedSentinel() case Err(:final failure)) {
        log.severe(
          message: 'Failed to write SP revoke sentinel',
          error: failure,
          trace: StackTrace.current,
        );
        return Err(failure);
      }
    }

    if (_repository.hasSession) {
      if (await _repository.dispose() case Err(:final failure)) {
        log.warning(
          'RevokeSpWalletUsecase: dispose failed, proceeding: '
          '${failure.logMessage}',
        );
      }
    }

    if (await _files.deleteOrphanBackups() case Err(:final failure)) {
      return _afterFailedDelete(failure);
    }
    if (await _files.deleteAccountDir() case Err(:final failure)) {
      return _afterFailedDelete(failure);
    }
    return const Ok(null);
  }

  /// The account dir is still (partly) on disk. Put the sentinel back, since
  /// the delete may have removed it before failing on a locked child, and tell
  /// observers to drop the SP card before reporting the failure.
  Future<Result<void, SpFailure>> _afterFailedDelete(SpFailure failure) async {
    log.severe(
      message:
          'Failed to delete SP account directory; sentinel left in place so '
          'wallet will not be loaded',
      error: failure,
      trace: StackTrace.current,
    );
    if (await _files.accountDirExists() case Ok(value: true)) {
      if (await _files.writeRevokedSentinel(skipIfPresent: true) case Err(
        failure: final sentinelFailure,
      )) {
        log.severe(
          message:
              'Failed to re-create SP revoke sentinel after delete failure; '
              'on-disk wallet may still be reloadable',
          error: sentinelFailure,
          trace: StackTrace.current,
        );
      }
    }
    _repository.notifySetupChanged();
    return Err(failure);
  }
}
