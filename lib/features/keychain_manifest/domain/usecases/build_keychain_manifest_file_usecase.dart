import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class BuildKeychainManifestFileUsecase {
  final KeychainManifestRepository _repository;

  const BuildKeychainManifestFileUsecase(this._repository);

  Future<Result<KeychainManifest, KeychainManifestFailure>> execute(
    Fingerprint parentFingerprint, {
    DateTime? now,
  }) async => switch (await _repository.fetch(parentFingerprint)) {
    Err(:final failure) => Err(failure),
    Ok(:final value) => Ok(
      KeychainManifest(
        parentFingerprint: parentFingerprint,
        generatedAt:
            (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000,
        entries: value,
      ).canonical(),
    ),
  };
}
