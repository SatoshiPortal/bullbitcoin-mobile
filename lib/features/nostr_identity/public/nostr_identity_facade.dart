import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart'
    show BackupCredential, InvalidBackupWordsException;
export 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';

/// The owner of the one backup credential.
///
/// Both identities and the words themselves come from the twelve words the
/// default seed derives, so a holder of those words reproduces everything this
/// facade serves without the seed.
class NostrIdentityFacade {
  final GetBackupIdentityPublicKeyUsecase _getPublicKey;
  final SignBackupIdentityHashUsecase _signHash;
  final BackupCredentialResolver _credential;

  const NostrIdentityFacade(
    this._getPublicKey,
    this._signHash,
    this._credential,
  );

  /// The whole credential of this wallet, for an operation that has to seal
  /// bytes and sign as the artifact author in one breath.
  ///
  /// The resolver is held directly rather than behind a use case that would
  /// only forward to it. Nothing caches the result: it carries the words.
  @useResult
  Future<Result<BackupCredential, NostrIdentityFailure>> backupCredential() =>
      _credential.resolve();

  /// The author of public backup artifacts, and the key a backup file is
  /// signed under.
  @useResult
  Future<Result<String, NostrIdentityFailure>> walletBackupPublicKey() =>
      _getPublicKey.execute(scope: BackupIdentityScope.nostr);

  @useResult
  Future<Result<String, NostrIdentityFailure>> signWalletBackupHash(
    String hashHex,
  ) => _signHash.execute(hashHex, scope: BackupIdentityScope.nostr);

  /// The name of the backup server account.
  @useResult
  Future<Result<String, NostrIdentityFailure>> walletBackupServerPublicKey() =>
      _getPublicKey.execute(scope: BackupIdentityScope.server);

  @useResult
  Future<Result<String, NostrIdentityFailure>> signWalletBackupServerHash(
    String hashHex,
  ) => _signHash.execute(hashHex, scope: BackupIdentityScope.server);

  /// The twelve backup words, derived at the point of use for a protected
  /// reveal screen. They are never cached, here or below.
  ///
  /// [expectedOriginFingerprint] refuses the reveal when this device's wallet
  /// is not the one the caller named, so another wallet's words are never
  /// presented as a given vault's credential.
  @useResult
  Future<Result<String, NostrIdentityFailure>> revealBackupWords({
    String? expectedOriginFingerprint,
  }) => _credential.revealWords(
    expectedOriginFingerprint: expectedOriginFingerprint,
  );
}
