import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';

final class FetchWalletBackupRemoteUsecase {
  final WalletBackupRemoteRepository _repository;
  final WalletBackupAuthenticator _authenticator;

  const FetchWalletBackupRemoteUsecase(this._repository, this._authenticator);

  /// Reads the account's head. With a [credential] the request is signed as
  /// that backup's server identity instead of the default seed's, which is how
  /// a words-only reader reaches a backup that is not this wallet's.
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> execute({
    BackupCredential? credential,
  }) async {
    final authentication = await _authenticator.sign(
      action: WalletBackupAction.fetch,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
      credential: credential,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.fetch(authentication: value),
    };
  }
}
