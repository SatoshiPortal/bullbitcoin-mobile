import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
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

final class RevealBackupIdentityUsecase {
  final NostrIdentityFacade _identities;

  const RevealBackupIdentityUsecase(this._identities);

  @useResult
  Future<Result<RevealedNostrSecret, KeychainManifestFailure>> execute(
    BackupIdentityRecord record,
  ) async {
    switch (await _identities.resolve()) {
      case Err():
        return const Err(KeychainManifestSeedFailure());
      case Ok(:final value):
        final publicKey = switch (record.kind) {
          BackupIdentityKind.artifact => value.artifactPublicKey,
          BackupIdentityKind.server => value.serverPublicKey,
        };
        if (value.sourceFingerprint != record.parentFingerprint ||
            publicKey != record.publicKey) {
          return const Err(KeychainManifestInvalidKeyFailure());
        }
        return Ok(
          RevealedNostrSecret(switch (record.kind) {
            BackupIdentityKind.artifact => value.revealArtifactNsec(),
            BackupIdentityKind.server => value.revealServerNsec(),
          }),
        );
    }
  }
}
