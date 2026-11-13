import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

final class GetBackupIdentitiesUsecase {
  final NostrIdentityFacade _identities;

  const GetBackupIdentitiesUsecase(this._identities);

  @useResult
  Future<Result<List<BackupIdentityRecord>, KeychainManifestFailure>>
  execute() async {
    switch (await _identities.resolve()) {
      case Err():
        return const Err(KeychainManifestSeedFailure());
      case Ok(:final value):
        final fingerprint = value.sourceFingerprint;
        if (fingerprint == null) {
          return const Err(KeychainManifestSeedFailure());
        }
        return Ok([
          BackupIdentityRecord(
            parentFingerprint: fingerprint,
            publicKey: value.artifactPublicKey,
            kind: BackupIdentityKind.artifact,
          ),
          BackupIdentityRecord(
            parentFingerprint: fingerprint,
            publicKey: value.serverPublicKey,
            kind: BackupIdentityKind.server,
          ),
        ]);
    }
  }
}
