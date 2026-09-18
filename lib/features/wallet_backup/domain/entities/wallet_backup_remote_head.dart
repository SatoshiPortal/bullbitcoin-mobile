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
    if (generation < 0 ||
        (generation == 0
            ? etag != null || ciphertext != null || updatedAt != null
            : etag == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(etag!))) {
      throw const FormatException('Invalid backup head');
    }
  }

  bool get found => ciphertext != null;
}
