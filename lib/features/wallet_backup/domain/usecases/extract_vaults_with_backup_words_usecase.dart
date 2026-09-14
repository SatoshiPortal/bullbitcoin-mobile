import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_words_extraction.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/fetch_wallet_backup_remote_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// Reads a backup with nothing but its twelve words.
///
/// This is the heir's path: no default seed, no fingerprint, no local database
/// and no wallet of their own. It authenticates the fetch as the credential's
/// server identity, decrypts with the credential's key and hands back the vault
/// records the backup carries.
///
/// It is deliberately inert locally. It touches no backup state, no recovery
/// fence and no writer checkpoint, so reading someone else's backup can never
/// move this installation's own. An unsupported envelope version is
/// reported as a failure and never blocks anything locally, because there is no
/// local account to block.
final class ExtractVaultsWithBackupWordsUsecase {
  final FetchWalletBackupRemoteUsecase _fetchRemote;
  final WalletBackupEncryptionRepository _encryption;
  final InspectVaultRecoveryPackage _inspectVault;

  const ExtractVaultsWithBackupWordsUsecase(
    this._fetchRemote,
    this._encryption,
    this._inspectVault,
  );

  /// The backup those [words] open, or null when the server holds none.
  @useResult
  Future<Result<WalletBackupWordsExtraction?, WalletBackupFailure>> execute(
    String words,
  ) async {
    final BackupCredential credential;
    try {
      credential = BackupCredential.fromWords(words);
    } on InvalidBackupWordsException {
      return const Err(WalletBackupInvalidBackupWordsFailure());
    }

    switch (await _fetchRemote.execute(credential: credential)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final ciphertext = value.ciphertext;
        if (ciphertext == null) return const Ok(null);
        switch (_encryption.decrypt(
          ciphertext: ciphertext,
          key: WalletBackupEncryptionKey(credential.encryptionKeyHex),
          expectedParentFingerprint: null,
        )) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: final snapshot):
            return switch (buildWalletBackupVaultSummaries(
              vaults: snapshot.vaults,
              inspectVault: _inspectVault,
            )) {
              Ok(:final value) => Ok(
                WalletBackupWordsExtraction(
                  vaults: value,
                  parentFingerprint: snapshot.parentFingerprint.hex,
                ),
              ),
              Err(:final failure) => Err(failure),
            };
        }
    }
  }
}
