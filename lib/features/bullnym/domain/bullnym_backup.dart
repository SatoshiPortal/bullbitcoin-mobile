import 'dart:convert';

enum BullnymBackupStream {
  walletBackup('wallet_backup');

  final String wireName;

  const BullnymBackupStream(this.wireName);
}

final class BullnymBackupCiphertext {
  static const minimumByteLength = 64;
  static const maximumByteLength = 2 * 1024 * 1024;

  final String value;
  final int byteLength;

  BullnymBackupCiphertext(String value)
    : value = value,
      byteLength = _validate(value);

  static int _validate(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(value, 'value');
    }
    late final List<int> bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      throw ArgumentError.value(value, 'value');
    }
    if (base64.encode(bytes) != value ||
        bytes.length < minimumByteLength ||
        bytes.length > maximumByteLength) {
      throw ArgumentError.value(value, 'value');
    }
    return bytes.length;
  }
}

final class BullnymBackupHead {
  final bool found;
  final int generation;
  final String? etag;
  final BullnymBackupCiphertext? ciphertext;
  final String? ciphertextSha256;
  final int? updatedAtSecs;

  BullnymBackupHead._({
    required this.found,
    required this.generation,
    required this.etag,
    required this.ciphertext,
    required this.ciphertextSha256,
    required this.updatedAtSecs,
  });

  factory BullnymBackupHead.absent({required int generation, String? etag}) {
    if (generation < 0 || (generation == 0) != (etag == null)) {
      throw ArgumentError('Invalid absent backup head');
    }
    return BullnymBackupHead._(
      found: false,
      generation: generation,
      etag: etag,
      ciphertext: null,
      ciphertextSha256: null,
      updatedAtSecs: null,
    );
  }

  factory BullnymBackupHead.present({
    required int generation,
    required String etag,
    required BullnymBackupCiphertext ciphertext,
    required String ciphertextSha256,
    required int updatedAtSecs,
  }) {
    if (generation <= 0 || updatedAtSecs < 0) {
      throw ArgumentError('Invalid present backup head');
    }
    return BullnymBackupHead._(
      found: true,
      generation: generation,
      etag: etag,
      ciphertext: ciphertext,
      ciphertextSha256: ciphertextSha256,
      updatedAtSecs: updatedAtSecs,
    );
  }
}

final class BullnymBackupStoreReceipt {
  final int generation;
  final String etag;

  const BullnymBackupStoreReceipt(this.generation, this.etag);
}

final class BullnymBackupDeleteReceipt {
  final int generation;
  final String etag;

  const BullnymBackupDeleteReceipt(this.generation, this.etag);
}
