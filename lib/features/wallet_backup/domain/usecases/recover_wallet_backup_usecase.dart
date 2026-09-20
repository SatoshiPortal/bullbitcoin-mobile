import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

final class RecoverWalletBackupUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupRemoteRepository _remote;
  final WalletBackupCodecRepository _codec;
  final ApplyWalletBackupSnapshotUsecase _apply;
  const RecoverWalletBackupUsecase({
    required this._operations,
    required this._identity,
    required this._state,
    required this._remote,
    required this._codec,
    required this._apply,
  });

  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> execute(
    WalletBackupInspection inspection, {
    String? words,
    bool enableAfterRecovery = false,
    Map<String, String?> initialWalletLabels = const {},
  }) => _operations.run(() async {
    final resolved = words == null
        ? await _identity.resolve()
        : _identity.fromWords(words);
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final credential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    if (credential.serverPublicKey != inspection.identity) {
      return const Err(WalletBackupCredentialFailure());
    }
    if (enableAfterRecovery &&
        !await _isCurrentIdentity(credential.serverPublicKey)) {
      return const Err(WalletBackupCredentialFailure());
    }
    final fetched = await _remote.fetch(credential);
    if (fetched case Err(:final failure)) return Err(failure);
    final head =
        (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    if (!head.sameObjectAs(inspection.head)) {
      return const Err(WalletBackupConflictFailure());
    }
    if (head.ciphertext == null) return const Err(WalletBackupMissingFailure());
    final decoded = _codec.decrypt(head.ciphertext!, credential);
    if (decoded case Err(:final failure)) return Err(failure);
    final snapshot =
        (decoded as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
    final applied = await _apply.execute(
      snapshot,
      initialWalletLabels: initialWalletLabels,
      revalidate: () async => switch (await _remote.fetch(credential)) {
        Err(:final failure) => Err(failure),
        Ok(:final value) => Ok(value.sameObjectAs(head)),
      },
    );
    if (applied case Err(:final failure)) return Err(failure);
    final result =
        (applied as Ok<WalletBackupRecovery, WalletBackupFailure>).value;
    if (!result.complete) return Ok(result);
    final hashed = _codec.contentHash(snapshot);
    if (hashed case Err(:final failure)) return Err(failure);
    final hash = (hashed as Ok<String, WalletBackupFailure>).value;
    final current = await _state.get(credential.serverPublicKey);
    if (current case Err(:final failure)) return Err(failure);
    final local = (current as Ok<WalletBackupState, WalletBackupFailure>).value;
    if (local.checkpoint?.etag == head.etag) {
      if (local.confirmedContentHash != hash) {
        return const Err(WalletBackupChangedFailure());
      }
    } else {
      final acknowledged = await _state.recordPublication(
        identity: credential.serverPublicKey,
        expectedEtag: local.checkpoint?.etag,
        checkpoint: WalletBackupCheckpoint(
          generation: head.generation,
          etag: head.etag!,
          ciphertextHash: head.ciphertext!.hash,
        ),
        contentHash: hash,
        succeededAt: head.updatedAt ?? DateTime.now().toUtc(),
      );
      if (acknowledged case Err(:final failure)) return Err(failure);
    }
    if (enableAfterRecovery) {
      if (!await _isCurrentIdentity(credential.serverPublicKey)) {
        return const Err(WalletBackupCredentialFailure());
      }
      if (await _state.setEnabled(true) case Err(:final failure)) {
        return Err(failure);
      }
    }
    return Ok(result);
  }, name: WalletBackupOperation.recover);

  Future<bool> _isCurrentIdentity(String identity) async =>
      switch (await _identity.resolve()) {
        Ok(:final value) => value.serverPublicKey == identity,
        Err() => false,
      };
}
