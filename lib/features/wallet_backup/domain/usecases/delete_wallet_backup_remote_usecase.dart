import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';

final class DeleteWalletBackupRemoteUsecase {
  final WalletBackupRemoteRepository _repository;
  final WalletBackupAuthenticator _authenticator;

  const DeleteWalletBackupRemoteUsecase(this._repository, this._authenticator);

  /// Deletes the remote object, or reports the tombstone [current] already is.
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> execute({
    required WalletBackupRemoteCheckpoint current,
  }) async {
    if (!current.found) return Ok(current);
    final authentication = await _authenticator.sign(
      action: WalletBackupAction.delete,
      generation: current.generation + 1,
      expectedEtag: current.etag,
      ciphertextSha256: '',
      ciphertextBytes: 0,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.delete(
        authentication: value,
        current: current,
      ),
    };
  }
}
