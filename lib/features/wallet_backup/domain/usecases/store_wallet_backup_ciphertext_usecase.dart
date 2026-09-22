import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// Automatic publication and explicit file replacement share the same verified
/// write. Their callers retain their own consent, queue and recovery-fence rules.
final class StoreWalletBackupCiphertextUsecase {
  final WalletBackupRemoteRepository _remote;
  final WalletBackupCodecRepository _codec;
  const StoreWalletBackupCiphertextUsecase({
    required this._remote,
    required this._codec,
  });

  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> execute(
    BackupCredential credential,
    WalletBackupCiphertext ciphertext, {
    required WalletBackupRemoteHead current,
    required String contentHash,
  }) async {
    if (current.generation == 0x7fffffffffffffff) {
      return const Err(WalletBackupInvalidFailure());
    }
    final stored = await _remote.store(
      credential,
      ciphertext,
      generation: current.generation + 1,
      expectedEtag: current.etag,
    );
    if (stored case Err(:final failure)) return Err(failure);
    final receipt =
        (stored as Ok<WalletBackupCheckpoint, WalletBackupFailure>).value;
    final fetched = await _remote.fetch(credential);
    if (fetched case Err(:final failure)) return Err(failure);
    final confirmed =
        (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    if (receipt.generation != current.generation + 1 ||
        confirmed.generation != receipt.generation ||
        confirmed.etag != receipt.etag ||
        confirmed.ciphertext?.hash != ciphertext.hash) {
      return const Err(WalletBackupConflictFailure());
    }
    final decoded = _codec.decrypt(confirmed.ciphertext!, credential);
    if (decoded case Err(:final failure)) return Err(failure);
    final hashed = _codec.contentHash(
      (decoded as Ok<WalletBackupSnapshot, WalletBackupFailure>).value,
    );
    if (hashed case Err(:final failure)) return Err(failure);
    return (hashed as Ok<String, WalletBackupFailure>).value == contentHash
        ? Ok(confirmed)
        : const Err(WalletBackupInvalidFailure());
  }
}
