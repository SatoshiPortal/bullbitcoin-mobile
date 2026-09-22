import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/capture_keychain_manifest_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../nostr_identity/fixtures/backup_credential_vectors.dart';

class _Repository extends Fake implements KeychainManifestRepository {
  bool called = false;
  @override
  Future<Result<CapturedKeychainManifest, KeychainManifestFailure>> capture({
    required String sourceFingerprint,
    required String artifactPublicKey,
    required String serverPublicKey,
  }) async {
    called = true;
    return const Err(KeychainManifestStorageFailure());
  }
}

void main() {
  test(
    'words-only credentials cannot assign this device inventory an invented parent origin',
    () async {
      final repository = _Repository();
      final result = await CaptureKeychainManifestUsecase(
        repository,
      ).execute(BackupCredential.fromWords(backupCredentialVectorWords));
      expect(result, isA<Err>());
      expect(repository.called, isFalse);
    },
  );
}
