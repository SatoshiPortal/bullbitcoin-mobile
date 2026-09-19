import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/store_wallet_backup_ciphertext_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

final class RecoverWalletBackupFileUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupRemoteRepository _remote;
  final WalletBackupCodecRepository _codec;
  final DecodeWalletBackupFileUsecase _decode;
  final ApplyWalletBackupSnapshotUsecase _apply;
  final RecoverWalletBackupUsecase _recoverRemote;

  const RecoverWalletBackupFileUsecase({
    required this._operations,
    required this._identity,
    required this._state,
    required this._remote,
    required this._codec,
    required this._decode,
    required this._apply,
    required this._recoverRemote,
  });

  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> execute(
    String encodedFile, {
    required WalletBackupFileComparison comparison,
    required WalletBackupImportSource source,
    required bool confirmed,
    String? words,
  }) async {
    if (!confirmed) return const Err(WalletBackupConfirmationRequiredFailure());
    if (source == WalletBackupImportSource.server) {
      final inspection = comparison.server;
      if (inspection?.snapshot == null) {
        return const Err(WalletBackupMissingFailure());
      }
      // The remote entry point owns the same queue and revalidates this exact
      // inspection. Do not nest a second queued operation around it.
      return _recoverRemote.execute(inspection!, words: words);
    }
    return _operations.run(() => _recoverFile(encodedFile, comparison, words));
  }

  Future<Result<WalletBackupRecovery, WalletBackupFailure>> _recoverFile(
    String source,
    WalletBackupFileComparison comparison,
    String? words,
  ) async {
    final decoded = await _decode.execute(source, words: words);
    if (decoded case Err(:final failure)) return Err(failure);
    final file = (decoded as Ok<WalletBackupFile, WalletBackupFailure>).value;
    final hashResult = _codec.contentHash(file.snapshot);
    if (hashResult case Err(:final failure)) return Err(failure);
    final hash = (hashResult as Ok<String, WalletBackupFailure>).value;
    final comparedHash = _codec.contentHash(comparison.file.snapshot);
    if (comparedHash case Err(:final failure)) return Err(failure);
    if ((comparedHash as Ok<String, WalletBackupFailure>).value != hash) {
      return const Err(WalletBackupChangedFailure());
    }
    final controlResult = await _state.getControl();
    if (controlResult case Err(:final failure)) return Err(failure);
    final control =
        (controlResult as Ok<WalletBackupControl, WalletBackupFailure>).value;
    if (control.enabled != true) return _apply.execute(file.snapshot);
    if (!comparison.automaticBackupEnabled) {
      return const Err(WalletBackupChangedFailure());
    }

    final resolved = await _identity.resolve();
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final credential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    if (file.snapshot.manifest.backupIdentities.any(
      (key) =>
          key.publicKey !=
          (key.kind == BackupIdentityKind.artifact
              ? credential.artifactPublicKey
              : credential.serverPublicKey),
    )) {
      return const Err(WalletBackupCredentialFailure());
    }
    final fetched = await _remote.fetch(credential);
    if (fetched case Err(:final failure)) {
      // Only a comparison that already showed the server unavailable permits
      // explicit offline recovery with automatic backup still enabled.
      if (comparison.server != null) return Err(failure);
      return (await _apply.execute(
        file.snapshot,
        keepRecoveryIncomplete: true,
      )).map(
        (result) => result.complete ? result.withFailure(failure) : result,
      );
    }
    final head =
        (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    if (comparison.server == null) {
      return const Err(WalletBackupChangedFailure());
    }
    var alreadyStored = false;
    if (head.ciphertext != null) {
      final remoteSnapshot = _codec.decrypt(head.ciphertext!, credential);
      if (remoteSnapshot case Err(:final failure)) return Err(failure);
      final remoteHash = remoteSnapshot.fold(
        _codec.contentHash,
        (failure) => Err<String, WalletBackupFailure>(failure),
      );
      if (remoteHash case Err(:final failure)) return Err(failure);
      alreadyStored =
          (remoteHash as Ok<String, WalletBackupFailure>).value == hash;
    }
    // Identical authenticated content also reconciles a lost successful reply.
    if (!alreadyStored && !head.sameObjectAs(comparison.server!.head)) {
      return const Err(WalletBackupConflictFailure());
    }
    if (!alreadyStored && head.generation == 0x7fffffffffffffff) {
      return const Err(WalletBackupInvalidFailure());
    }
    final applied = await _apply.execute(
      file.snapshot,
      keepRecoveryIncomplete: true,
      revalidate: () async => switch (await _remote.fetch(credential)) {
        Err(:final failure) => Err(failure),
        Ok(:final value) => Ok(value.sameObjectAs(head)),
      },
    );
    if (applied case Err(:final failure)) return Err(failure);
    final result =
        (applied as Ok<WalletBackupRecovery, WalletBackupFailure>).value;
    if (!result.complete) return Ok(result);
    final latestControl = await _state.getControl();
    if (latestControl case Err(:final failure)) {
      return Ok(result.withFailure(failure));
    }
    if ((latestControl as Ok<WalletBackupControl, WalletBackupFailure>)
            .value
            .enabled !=
        true) {
      return (await _state.setRecoveryIncomplete(false)).map((_) => result);
    }
    var confirmed = head;
    if (!alreadyStored) {
      final encrypted = _codec.encrypt(file.snapshot, credential);
      if (encrypted case Err(:final failure)) {
        return Ok(result.withFailure(failure));
      }
      final stored =
          await StoreWalletBackupCiphertextUsecase(
            remote: _remote,
            codec: _codec,
          ).execute(
            credential,
            (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>)
                .value,
            current: head,
            contentHash: hash,
          );
      if (stored case Err(:final failure)) {
        return Ok(result.withFailure(failure));
      }
      confirmed =
          (stored as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    }
    if (await _state.setRecoveryIncomplete(false) case Err(:final failure)) {
      return Ok(result.withFailure(failure));
    }
    final loaded = await _state.get(credential.serverPublicKey);
    if (loaded case Err(:final failure)) return Err(failure);
    final local = (loaded as Ok<WalletBackupState, WalletBackupFailure>).value;
    if (local.checkpoint?.etag == confirmed.etag) {
      if (local.confirmedContentHash != hash) {
        return const Err(WalletBackupChangedFailure());
      }
    } else {
      final saved = await _state.recordPublication(
        identity: credential.serverPublicKey,
        expectedEtag: local.checkpoint?.etag,
        checkpoint: WalletBackupCheckpoint(
          generation: confirmed.generation,
          etag: confirmed.etag!,
          ciphertextHash: confirmed.ciphertext!.hash,
        ),
        contentHash: hash,
        succeededAt: confirmed.updatedAt ?? DateTime.now().toUtc(),
      );
      if (saved case Err(:final failure)) return Err(failure);
    }
    return Ok(result);
  }
}
