import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class FetchWalletBackupSnapshotUsecase {
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final WalletBackupStateRepository _state;

  const FetchWalletBackupSnapshotUsecase({
    required this._resolveKey,
    required this._encryption,
    required this._state,
  });

  @useResult
  Future<Result<WalletBackupSnapshot?, WalletBackupFailure>> execute(
    WalletBackupRemoteHead remote,
  ) async {
    final keyResult = await _resolveKey.execute();
    final WalletBackupKey backupKey;
    switch (keyResult) {
      case Ok(:final value):
        backupKey = value;
      case Err(:final failure):
        return Err(failure);
    }
    final ciphertext = remote.ciphertext;
    if (ciphertext == null) return const Ok(null);

    final decryptResult = _encryption.decrypt(
      ciphertext: ciphertext,
      key: backupKey.encryptionKey,
      expectedParentFingerprint: backupKey.parentFingerprint,
    );
    switch (decryptResult) {
      case Err(
        failure: final WalletBackupUnsupportedEnvelopeVersionFailure failure,
      ):
        final blockResult = await _state.blockUnsupportedVersion(
          failure.version,
        );
        if (blockResult case Err(:final failure)) return Err(failure);
        return Err(failure);
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(value);
    }
  }
}
