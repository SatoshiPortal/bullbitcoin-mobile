import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

final class CaptureKeychainManifestUsecase {
  final KeychainManifestRepository _repository;

  const CaptureKeychainManifestUsecase(this._repository);

  @useResult
  Future<Result<CapturedKeychainManifest, KeychainManifestFailure>> execute(
    BackupCredential credential,
  ) {
    final fingerprint = credential.sourceFingerprint;
    if (fingerprint == null) {
      return Future.value(const Err(KeychainManifestSeedFailure()));
    }
    return _repository.capture(
      sourceFingerprint: fingerprint,
      artifactPublicKey: credential.artifactPublicKey,
      serverPublicKey: credential.serverPublicKey,
    );
  }
}
