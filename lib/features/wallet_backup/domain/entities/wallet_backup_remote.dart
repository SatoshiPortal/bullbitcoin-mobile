import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';

final class WalletBackupRemoteHead {
  final int generation;
  final String? etag;
  final WalletBackupCiphertext? ciphertext;
  final String? ciphertextSha256;
  final int? updatedAtSecs;

  bool get found => ciphertext != null;

  WalletBackupRemoteHead._({
    required this.generation,
    required this.etag,
    required this.ciphertext,
    required this.ciphertextSha256,
    required this.updatedAtSecs,
  }) {
    if (generation < 0) {
      throw ArgumentError.value(
        generation,
        'generation',
        'wallet backup generation must be non-negative',
      );
    }
    if (found &&
        (generation == 0 ||
            !_isHash(etag) ||
            !_isHash(ciphertextSha256) ||
            updatedAtSecs == null ||
            updatedAtSecs! < 0)) {
      throw ArgumentError('wallet backup live head is inconsistent');
    }
    if (!found &&
        (ciphertextSha256 != null ||
            updatedAtSecs != null ||
            (generation == 0 ? etag != null : !_isHash(etag)))) {
      throw ArgumentError('wallet backup absent head is inconsistent');
    }
  }

  factory WalletBackupRemoteHead.absent({
    required int generation,
    required String? etag,
  }) => WalletBackupRemoteHead._(
    generation: generation,
    etag: etag,
    ciphertext: null,
    ciphertextSha256: null,
    updatedAtSecs: null,
  );

  factory WalletBackupRemoteHead.present({
    required int generation,
    required String etag,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
    required int updatedAtSecs,
  }) => WalletBackupRemoteHead._(
    generation: generation,
    etag: etag,
    ciphertext: ciphertext,
    ciphertextSha256: ciphertextSha256,
    updatedAtSecs: updatedAtSecs,
  );
}

final class WalletBackupRemoteCheckpoint {
  final int generation;
  final String etag;

  WalletBackupRemoteCheckpoint({required this.generation, required String etag})
    : etag = etag.trim().toLowerCase() {
    if (generation <= 0) {
      throw ArgumentError.value(
        generation,
        'generation',
        'wallet backup checkpoint generation must be positive',
      );
    }
    if (!_isHash(this.etag)) {
      throw ArgumentError.value(
        etag,
        'etag',
        'wallet backup checkpoint ETag must be 32-byte lowercase hex',
      );
    }
  }
}

final class WalletBackupSyncResult {
  final WalletBackupRemoteCheckpoint checkpoint;
  final String contentHash;

  WalletBackupSyncResult({
    required this.checkpoint,
    required String contentHash,
  }) : contentHash = contentHash.trim().toLowerCase() {
    if (!_isHash(this.contentHash)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'wallet backup content hash must be 32-byte lowercase hex',
      );
    }
  }
}

bool _isHash(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
