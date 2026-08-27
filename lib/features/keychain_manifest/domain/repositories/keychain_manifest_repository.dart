import 'dart:async';

import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum KeychainManifestWriteOrigin { local, recovery }

abstract interface class KeychainManifestRepository {
  Stream<void> watchLocalChanges();

  @useResult
  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>> fetch(
    Fingerprint parentFingerprint,
  );

  @useResult
  Future<Result<void, KeychainManifestFailure>> save(
    List<KeychainManifestEntry> entries, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  });

  @useResult
  Future<Result<void, KeychainManifestFailure>> updateNostrMetadata({
    required Fingerprint parentFingerprint,
    required String entryId,
    required String purpose,
    String? description,
    required int updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  });

  Future<void> close();
}
