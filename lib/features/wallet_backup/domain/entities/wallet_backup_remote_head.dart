import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';

final class WalletBackupRemoteHead {
  final int generation;
  final String? etag;
  final WalletBackupCiphertext? ciphertext;
  final DateTime? updatedAt;

  WalletBackupRemoteHead({
    required this.generation,
    required this.etag,
    this.ciphertext,
    this.updatedAt,
  }) {
    final tag = etag;
    if (generation < 0 ||
        (generation == 0
            ? tag != null || ciphertext != null || updatedAt != null
            : tag == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(tag))) {
      throw const FormatException('Invalid backup head');
    }
  }

  bool get found => ciphertext != null;

  bool sameObjectAs(WalletBackupRemoteHead other) =>
      generation == other.generation &&
      etag == other.etag &&
      ciphertext?.hash == other.ciphertext?.hash;
}
