import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:meta/meta.dart';

/// Derives the twelve backup words for a protected reveal.
///
/// The caller shows them and drops them; nothing here or below keeps a copy.
class RevealBackupWordsUsecase {
  final BackupCredentialResolver _resolver;

  const RevealBackupWordsUsecase(this._resolver);

  @useResult
  Future<Result<String, NostrIdentityFailure>> execute() =>
      _resolver.revealWords();
}
