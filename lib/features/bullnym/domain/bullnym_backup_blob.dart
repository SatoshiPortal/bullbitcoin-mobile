import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';

final _backupHashPattern = RegExp(r'^[0-9a-f]{64}$');

enum BullnymBackupStream {
  keychainManifest('keychain_manifest'),
  walletMetadata('wallet_metadata');

  final String wireName;

  const BullnymBackupStream(this.wireName);
}

final class BullnymBackupHead {
  final bool found;
  final int generation;
  final String? etag;
  final AuthenticatedBackupCiphertext? ciphertext;
  final String? ciphertextSha256;
  final int? updatedAtSecs;

  BullnymBackupHead._({
    required this.found,
    required this.generation,
    required this.etag,
    required this.ciphertext,
    required this.ciphertextSha256,
    required this.updatedAtSecs,
  }) {
    if (generation < 0 || (found && generation == 0)) {
      throw ArgumentError.value(generation, 'generation');
    }
    if (found &&
        (etag == null ||
            ciphertext == null ||
            ciphertextSha256 == null ||
            updatedAtSecs == null)) {
      throw ArgumentError('Found backup head is incomplete');
    }
    if (!found &&
        (ciphertext != null ||
            ciphertextSha256 != null ||
            (generation == 0 ? etag != null : etag == null))) {
      throw ArgumentError('Absent backup head is inconsistent');
    }
    final etagValue = etag;
    if (etagValue != null && !_backupHashPattern.hasMatch(etagValue)) {
      throw ArgumentError.value(etagValue, 'etag');
    }
    final ciphertextHash = ciphertextSha256;
    if (ciphertextHash != null &&
        !_backupHashPattern.hasMatch(ciphertextHash)) {
      throw ArgumentError.value(ciphertextHash, 'ciphertextSha256');
    }
    final updatedAt = updatedAtSecs;
    if (updatedAt != null && updatedAt < 0) {
      throw ArgumentError.value(updatedAt, 'updatedAtSecs');
    }
  }

  factory BullnymBackupHead.absent({
    required int generation,
    required String? etag,
  }) => BullnymBackupHead._(
    found: false,
    generation: generation,
    etag: etag,
    ciphertext: null,
    ciphertextSha256: null,
    updatedAtSecs: null,
  );

  factory BullnymBackupHead.present({
    required int generation,
    required String etag,
    required AuthenticatedBackupCiphertext ciphertext,
    required String ciphertextSha256,
    required int updatedAtSecs,
  }) => BullnymBackupHead._(
    found: true,
    generation: generation,
    etag: etag,
    ciphertext: ciphertext,
    ciphertextSha256: ciphertextSha256,
    updatedAtSecs: updatedAtSecs,
  );
}

final class BullnymBackupStoreReceipt {
  final int generation;
  final String etag;

  const BullnymBackupStoreReceipt({
    required this.generation,
    required this.etag,
  });
}

final class BullnymBackupDeleteReceipt {
  final int generation;
  final String etag;

  const BullnymBackupDeleteReceipt({
    required this.generation,
    required this.etag,
  });
}
