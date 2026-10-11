import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

final class DeleteWalletBackupUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupRemoteRepository _remote;
  const DeleteWalletBackupUsecase({
    required this._operations,
    required this._identity,
    required this._state,
    required this._remote,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute({
    required bool confirmed,
  }) => _operations.run(() async {
    if (!confirmed) return const Err(WalletBackupConfirmationRequiredFailure());
    switch (await _state.getControl()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final control) when control.enabled == true:
        return const Err(WalletBackupDeleteRequiresDisabledFailure());
      case Ok():
        break;
    }
    final resolved = await _identity.resolve();
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final credential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    final current = await _state.get(credential.serverPublicKey);
    if (current case Err(:final failure)) return Err(failure);
    final local = (current as Ok<WalletBackupState, WalletBackupFailure>).value;
    final fetched = await _remote.fetch(credential);
    if (fetched case Err(:final failure)) return Err(failure);
    final head =
        (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    if (head.found) {
      if (head.generation == 0x7fffffffffffffff) {
        return const Err(WalletBackupInvalidFailure());
      }
      final deleted = await _remote.delete(
        credential,
        generation: head.generation + 1,
        expectedEtag: head.etag!,
      );
      if (deleted case Err(:final failure)) return Err(failure);
      final receipt =
          (deleted as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
      final readback = await _remote.fetch(credential);
      if (readback case Err(:final failure)) return Err(failure);
      final checked =
          (readback as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
      if (checked.found || !checked.sameObjectAs(receipt)) {
        return const Err(WalletBackupConflictFailure());
      }
    }
    if (local.checkpoint == null) return const Ok(null);
    return _state.clearRemoteCheckpoint(
      identity: credential.serverPublicKey,
      expectedEtag: local.checkpoint!.etag,
    );
  }, name: WalletBackupOperation.delete);
}
