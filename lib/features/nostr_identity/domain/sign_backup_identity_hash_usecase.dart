import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_identity_scope.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:meta/meta.dart';

class SignBackupIdentityHashUsecase {
  static final _hashPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final BackupCredentialResolver _resolver;

  const SignBackupIdentityHashUsecase(this._resolver);

  @useResult
  Future<Result<String, NostrIdentityFailure>> execute(
    String hashHex, {
    required BackupIdentityScope scope,
  }) async {
    if (!_hashPattern.hasMatch(hashHex)) {
      return const Err(NostrIdentityInvalidHashFailure());
    }
    return (await _resolver.resolve()).map(
      (credential) => switch (scope) {
        BackupIdentityScope.nostr => credential.signNostrHash(hashHex),
        BackupIdentityScope.server => credential.signServerHash(hashHex),
      },
    );
  }
}
