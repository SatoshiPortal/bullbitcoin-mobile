import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:meta/meta.dart';

export '../domain/backup_credential.dart';
export '../domain/nostr_identity_failure.dart';

class NostrIdentityFacade {
  final BackupCredentialResolver _resolver;

  const NostrIdentityFacade(this._resolver);

  @useResult
  Future<Result<BackupCredential, NostrIdentityFailure>> resolve() =>
      _resolver.resolve();

  @useResult
  Result<BackupCredential, NostrIdentityFailure> fromWords(String input) =>
      _resolver.fromWords(input);
}
