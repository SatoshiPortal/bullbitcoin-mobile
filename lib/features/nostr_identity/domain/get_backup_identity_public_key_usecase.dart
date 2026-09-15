import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:meta/meta.dart';

class GetBackupIdentityPublicKeyUsecase {
  final BackupCredentialResolver _resolver;

  const GetBackupIdentityPublicKeyUsecase(this._resolver);

  @useResult
  Future<Result<String, NostrIdentityFailure>> execute({
    required BackupIdentityScope scope,
  }) async => (await _resolver.resolve()).map(
    (credential) => switch (scope) {
      BackupIdentityScope.nostr => credential.nostrPublicKeyHex,
      BackupIdentityScope.server => credential.serverPublicKeyHex,
    },
  );
}
