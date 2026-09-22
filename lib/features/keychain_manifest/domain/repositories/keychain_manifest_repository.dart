import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:meta/meta.dart';

abstract interface class KeychainManifestRepository {
  @useResult
  Future<Result<CapturedKeychainManifest, KeychainManifestFailure>> capture({
    required String sourceFingerprint,
    required String artifactPublicKey,
    required String serverPublicKey,
  });
  @useResult
  Future<Result<void, KeychainManifestFailure>> restorePublicRecords(
    KeychainManifest manifest,
  );
}
