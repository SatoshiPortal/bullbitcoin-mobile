import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class InspectWalletBackupUsecase {
  final NostrIdentityFacade _identity;
  final WalletBackupRemoteRepository _remote;
  final WalletBackupCodecRepository _codec;
  const InspectWalletBackupUsecase({
    required this._identity,
    required this._remote,
    required this._codec,
  });

  @useResult
  Future<Result<WalletBackupInspection, WalletBackupFailure>> execute({
    String? words,
  }) async {
    final resolved = words == null
        ? await _identity.resolve()
        : _identity.fromWords(words);
    if (resolved case Err()) return const Err(WalletBackupCredentialFailure());
    final credential =
        (resolved as Ok<BackupCredential, NostrIdentityFailure>).value;
    final fetched = await _remote.fetch(credential);
    if (fetched case Err(:final failure)) return Err(failure);
    final head =
        (fetched as Ok<WalletBackupRemoteHead, WalletBackupFailure>).value;
    WalletBackupSnapshot? snapshot;
    if (head.ciphertext case final ciphertext?) {
      switch (_codec.decrypt(ciphertext, credential)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          snapshot = value;
      }
    }
    return Ok(
      WalletBackupInspection(
        identity: credential.serverPublicKey,
        head: head,
        snapshot: snapshot,
      ),
    );
  }
}
