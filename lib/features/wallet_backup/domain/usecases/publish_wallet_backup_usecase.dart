import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Publishes the local snapshot as the authoritative remote document.
///
/// The published bytes are exactly the local snapshot: nothing is merged with
/// what the remote holds, so a record removed locally is gone from the next
/// publication and a recovery cannot resurrect it (decision 1, spec F1/F2).
///
/// With a trusted checkpoint the store goes straight out, with no preceding
/// fetch (spec 19.3, F7). A head conflict means another installation published
/// in the meantime: the head is fetched and authenticated once, a durable
/// needs-attention state is recorded, local work stays dirty, and the decision
/// is left to the user (spec 19.4, decision 3).
final class PublishWalletBackupUsecase {
  final BuildWalletBackupSnapshotUsecase _buildSnapshot;
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final FetchWalletBackupRemoteUsecase _fetchRemote;
  final StoreWalletBackupRemoteUsecase _storeRemote;
  final FetchWalletBackupSnapshotUsecase _readRemoteSnapshot;
  final WalletBackupStateRepository _state;

  const PublishWalletBackupUsecase({
    required this._buildSnapshot,
    required this._resolveKey,
    required this._encryption,
    required this._fetchRemote,
    required this._storeRemote,
    required this._readRemoteSnapshot,
    required this._state,
  });

  @useResult
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> execute(
    WalletBackupRemoteCheckpoint? checkpoint,
  ) async {
    final WalletBackupKey backupKey;
    switch (await _resolveKey.execute()) {
      case Ok(:final value):
        backupKey = value;
      case Err(:final failure):
        return Err(failure);
    }

    var current = checkpoint;
    if (current == null) {
      switch (await _fetchRemote.execute()) {
        case Ok(:final value):
          current = value.checkpoint;
        case Err(:final failure):
          return Err(failure);
      }
    }

    final WalletBackupSnapshot local;
    switch (await _buildSnapshot.execute(
      parentFingerprint: backupKey.parentFingerprint,
      allowEmpty: true,
    )) {
      case Ok(:final value):
        local = value;
      case Err(:final failure):
        return Err(failure);
    }

    final WalletBackupCiphertext ciphertext;
    switch (_encryption.encrypt(
      envelope: local,
      key: backupKey.encryptionKey,
    )) {
      case Ok(:final value):
        ciphertext = value;
      case Err(:final failure):
        return Err(failure);
    }

    return switch (await _storeRemote.execute(
      current: current,
      ciphertext: ciphertext,
    )) {
      Ok(:final value) => Ok(value),
      Err(failure: WalletBackupHeadConflictFailure()) => _recordConflict(),
      Err(:final failure) => Err(failure),
    };
  }

  /// Fetches the head that beat this publication, authenticates it, and leaves
  /// the feature needing attention. The remote is never overwritten here.
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>>
  _recordConflict() async {
    final WalletBackupRemoteHead head;
    switch (await _fetchRemote.execute()) {
      case Ok(:final value):
        head = value;
      case Err(:final failure):
        return Err(failure);
    }

    final decoded = await _readRemoteSnapshot.execute(head);
    if (await _state.saveRemoteCheckpoint(head.checkpoint) case Err(
      :final failure,
    )) {
      return Err(failure);
    }
    // An unsupported version is its own durable block, already recorded while
    // decoding. Adding needs-attention on top would mask it behind the
    // recovery fence, so the version failure is reported as it stands.
    if (decoded case Err(:final failure)) return Err(failure);

    // Local work stays dirty on its own: uploadedRevision never advanced, so
    // the head conflict only has to raise the fence.
    if (await _state.setRecoveryState(WalletBackupRecoveryState.needsAttention)
        case Err(:final failure)) {
      return Err(failure);
    }
    return const Err(WalletBackupHeadConflictFailure());
  }
}
