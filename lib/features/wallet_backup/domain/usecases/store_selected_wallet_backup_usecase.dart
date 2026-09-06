import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/wallet_backup_remote_usecases.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

/// Replaces the compared remote snapshot with the backup selected by the user.
final class StoreSelectedWalletBackupUsecase {
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final StoreWalletBackupRemoteUsecase _storeRemote;
  final WalletBackupStateRepository _state;

  const StoreSelectedWalletBackupUsecase(
    this._resolveKey,
    this._encryption,
    this._storeRemote,
    this._state,
  );

  Future<Result<void, WalletBackupFailure>> execute({
    required WalletBackupSnapshot selected,
    required WalletBackupRemoteCheckpoint? current,
  }) async {
    final backupKeyResult = await _resolveKey.execute();
    if (backupKeyResult case Err(:final failure)) return Err(failure);
    final backupKey = (backupKeyResult as Ok).value;
    if (backupKey.parentFingerprint != selected.parentFingerprint.hex) {
      return const Err(WalletBackupParentFingerprintMismatchFailure());
    }
    final encrypted = _encryption.encrypt(
      envelope: selected,
      key: backupKey.encryptionKey,
    );
    if (encrypted case Err(:final failure)) return Err(failure);
    final ciphertext = (encrypted as Ok).value;

    // Recovery is additive: local records absent from this file can survive.
    // Keep local state dirty until a full local snapshot has been published.
    final revision = await _state.recordLocalMutation();
    if (revision case Err(:final failure)) return Err(failure);
    final WalletBackupRemoteCheckpoint checkpoint;
    switch (await _storeRemote.execute(
      current: current,
      ciphertext: ciphertext,
    )) {
      case Ok(:final value):
        checkpoint = value;
      case Err(:final failure):
        return Err(failure);
    }
    return _state.saveRemoteCheckpoint(checkpoint);
  }
}
