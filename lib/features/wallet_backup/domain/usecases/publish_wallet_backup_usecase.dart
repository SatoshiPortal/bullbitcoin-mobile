import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

class PublishWalletBackupUsecase {
  final WalletBackupOperationQueue _operations;
  final NostrIdentityFacade _identity;
  final WalletBackupStateRepository _state;
  final WalletBackupSnapshotRepository _snapshots;
  final WalletBackupCodecRepository _codec;
  final WalletBackupRemoteRepository _remote;
  final DateTime Function() _now;
  _UnconfirmedPublication? _unconfirmed;

  PublishWalletBackupUsecase({
    required this._operations,
    required this._identity,
    required this._state,
    required this._snapshots,
    required this._codec,
    required this._remote,
    this._now = _utcNow,
  });

  /// Replace is an explicit user intent tied to the head they inspected. Normal
  /// automatic/Back up now calls never authorize overwriting a different head.
  @useResult
  Future<Result<WalletBackupPublication, WalletBackupFailure>> execute({
    bool force = false,
    WalletBackupRemoteHead? replace,
  }) => _operations.run(() => _publish(force: force, replace: replace));

  Future<Result<WalletBackupPublication, WalletBackupFailure>> _publish({
    required bool force,
    required WalletBackupRemoteHead? replace,
  }) async {
    switch (await _permitted()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Ok(WalletBackupPublication.inactive);
      case Ok():
        break;
    }
    final credentialResult = await _identity.resolve();
    if (credentialResult case Err()) {
      return const Err(WalletBackupCredentialFailure());
    }
    final credential =
        (credentialResult as Ok<BackupCredential, NostrIdentityFailure>).value;
    var revision = 0;
    final subscription = _snapshots.changes.listen((_) {
      if (revision >= 0) revision++;
    }, onError: (Object _) => revision = -1);
    try {
      final beforeCapture = revision;
      final capture = await _snapshots.capture(credential);
      if (capture case Err(:final failure)) return Err(failure);
      final snapshot =
          (capture as Ok<WalletBackupSnapshot, WalletBackupFailure>).value;
      final hashResult = _codec.contentHash(snapshot);
      if (hashResult case Err(:final failure)) return Err(failure);
      final hash = (hashResult as Ok<String, WalletBackupFailure>).value;
      if (revision < 0) return const Err(WalletBackupStorageFailure());
      if (revision != beforeCapture) {
        return const Ok(WalletBackupPublication.pending);
      }
      final stateResult = await _state.get(credential.serverPublicKey);
      if (stateResult case Err(:final failure)) return Err(failure);
      final state =
          (stateResult as Ok<WalletBackupState, WalletBackupFailure>).value;
      if (revision < 0) return const Err(WalletBackupStorageFailure());
      if (!force &&
          replace == null &&
          _unconfirmed?.identity != credential.serverPublicKey &&
          state.checkpoint != null &&
          state.confirmedContentHash == hash) {
        return revision == beforeCapture
            ? const Ok(WalletBackupPublication.upToDate)
            : const Ok(WalletBackupPublication.pending);
      }
      final fetched = await _remote.fetch(credential);
      if (fetched case Err(:final failure)) return Err(failure);
      final head =
          (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
      if (replace != null &&
          (replace.etag != head.etag ||
              replace.generation != head.generation)) {
        return const Err(WalletBackupConflictFailure());
      }
      String? remoteHash;
      if (head.ciphertext case final ciphertext?) {
        switch (_codec.decrypt(ciphertext, credential)) {
          case Ok(:final value):
            switch (_codec.contentHash(value)) {
              case Ok(:final value):
                remoteHash = value;
              case Err(:final failure):
                return Err(failure);
            }
          case Err():
            if (replace == null) {
              return const Err(WalletBackupConflictFailure());
            }
        }
      }
      final pending = _unconfirmed;
      if (pending != null &&
          pending.identity == credential.serverPublicKey &&
          pending.generation == head.generation &&
          pending.ciphertext.hash == head.ciphertext?.hash &&
          pending.contentHash == remoteHash) {
        final acknowledged = await _acknowledge(
          credential.serverPublicKey,
          state,
          head,
          pending.contentHash,
        );
        if (acknowledged case Err(:final failure)) return Err(failure);
        _unconfirmed = null;
        return await _finish(
          credential,
          pending.contentHash,
          () => revision,
          WalletBackupPublication.upToDate,
        );
      }
      if (head.found && remoteHash == hash) {
        final acknowledged = await _acknowledge(
          credential.serverPublicKey,
          state,
          head,
          hash,
        );
        if (acknowledged case Err(:final failure)) return Err(failure);
        _unconfirmed = null;
        return await _finish(
          credential,
          hash,
          () => revision,
          WalletBackupPublication.upToDate,
        );
      }
      if (replace == null &&
          (state.checkpoint?.etag != head.etag ||
              state.checkpoint == null && head.generation != 0)) {
        return const Err(WalletBackupConflictFailure());
      }
      if (head.generation == 0x7fffffffffffffff) {
        return const Err(WalletBackupInvalidFailure());
      }
      if (revision < 0) return const Err(WalletBackupStorageFailure());
      if (revision != beforeCapture) {
        return const Ok(WalletBackupPublication.pending);
      }
      switch (await _permitted()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: false):
          return const Ok(WalletBackupPublication.inactive);
        case Ok():
          break;
      }
      final encrypted = _codec.encrypt(snapshot, credential);
      if (encrypted case Err(:final failure)) return Err(failure);
      final ciphertext =
          (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>).value;
      final generation = head.generation + 1;
      _unconfirmed = _UnconfirmedPublication(
        credential.serverPublicKey,
        generation,
        ciphertext,
        hash,
      );
      final stored = await _remote.store(
        credential,
        ciphertext,
        generation: generation,
        expectedEtag: head.etag,
      );
      if (stored case Err(:final failure)) return Err(failure);
      final receipt =
          (stored as Ok<WalletBackupCheckpoint, WalletBackupFailure>).value;
      final readback = await _remote.fetch(credential);
      if (readback case Err(:final failure)) return Err(failure);
      final confirmed =
          (readback as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
      if (confirmed.generation != receipt.generation ||
          confirmed.etag != receipt.etag ||
          confirmed.ciphertext?.hash != ciphertext.hash) {
        return const Err(WalletBackupConflictFailure());
      }
      final decoded = _codec.decrypt(confirmed.ciphertext!, credential);
      if (decoded case Err(:final failure)) return Err(failure);
      final verifiedHash = _codec.contentHash(
        (decoded as Ok<WalletBackupSnapshot, WalletBackupFailure>).value,
      );
      if (verifiedHash case Err(:final failure)) return Err(failure);
      if ((verifiedHash as Ok<String, WalletBackupFailure>).value != hash) {
        return const Err(WalletBackupInvalidFailure());
      }
      final acknowledged = await _acknowledge(
        credential.serverPublicKey,
        state,
        confirmed,
        hash,
      );
      if (acknowledged case Err(:final failure)) return Err(failure);
      _unconfirmed = null;
      return await _finish(
        credential,
        hash,
        () => revision,
        WalletBackupPublication.published,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<Result<bool, WalletBackupFailure>> _permitted() async =>
      switch (await _state.getControl()) {
        Err(:final failure) => Err(failure),
        Ok(:final value) =>
          value.recoveryIncomplete
              ? const Err(WalletBackupIncompleteFailure())
              : Ok(value.enabled == true),
      };

  Future<Result<void, WalletBackupFailure>> _acknowledge(
    String identity,
    WalletBackupState local,
    WalletBackupRemoteHead confirmed,
    String contentHash,
  ) async {
    if (local.checkpoint?.etag == confirmed.etag) {
      return local.confirmedContentHash == contentHash
          ? const Ok(null)
          : const Err(WalletBackupChangedFailure());
    }

    return _state.recordPublication(
      identity: identity,
      expectedEtag: local.checkpoint?.etag,
      checkpoint: WalletBackupCheckpoint(
        generation: confirmed.generation,
        etag: confirmed.etag!,
        ciphertextHash: confirmed.ciphertext!.hash,
      ),
      contentHash: contentHash,
      succeededAt: confirmed.updatedAt ?? _now(),
    );
  }

  Future<Result<WalletBackupPublication, WalletBackupFailure>> _finish(
    BackupCredential original,
    String confirmedHash,
    int Function() revision,
    WalletBackupPublication outcome,
  ) async {
    switch (await _permitted()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Ok(WalletBackupPublication.inactive);
      case Ok():
        break;
    }
    final resolved = await _identity.resolve();
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final currentCredential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    if (currentCredential.serverPublicKey != original.serverPublicKey) {
      return const Ok(WalletBackupPublication.pending);
    }
    final beforeCapture = revision();
    if (beforeCapture < 0) return const Err(WalletBackupStorageFailure());
    final current = await _snapshots.capture(currentCredential);
    if (current case Err(:final failure)) return Err(failure);
    final hash = _codec.contentHash(
      (current as Ok<WalletBackupSnapshot, WalletBackupFailure>).value,
    );
    if (hash case Err(:final failure)) return Err(failure);
    if (revision() < 0) return const Err(WalletBackupStorageFailure());
    return (hash as Ok<String, WalletBackupFailure>).value == confirmedHash &&
            revision() == beforeCapture
        ? Ok(outcome)
        : const Ok(WalletBackupPublication.pending);
  }
}

// Only encrypted/public facts survive an uncertain response. No credential or
// plaintext is cached. A restart reconciles remote canonical content instead.
final class _UnconfirmedPublication {
  final String identity;
  final int generation;
  final WalletBackupCiphertext ciphertext;
  final String contentHash;
  const _UnconfirmedPublication(
    this.identity,
    this.generation,
    this.ciphertext,
    this.contentHash,
  );
}

DateTime _utcNow() => DateTime.now().toUtc();
