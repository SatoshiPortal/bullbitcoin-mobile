import 'dart:async';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';

typedef KeychainManifestSignHash = FutureOr<String> Function(String hashHex);

final class KeychainManifestBackupSigner {
  final String publicKeyHex;
  final KeychainManifestSignHash signHashHex;

  const KeychainManifestBackupSigner({
    required this.publicKeyHex,
    required this.signHashHex,
  });
}

final class KeychainManifestRemoteBackup {
  final int generation;
  final String? etag;
  final AuthenticatedBackupCiphertext? ciphertext;

  const KeychainManifestRemoteBackup({
    required this.generation,
    required this.etag,
    required this.ciphertext,
  });

  bool get found => ciphertext != null;
}

final class KeychainManifestRemoteCheckpoint {
  final int generation;
  final String etag;

  const KeychainManifestRemoteCheckpoint({
    required this.generation,
    required this.etag,
  });
}
