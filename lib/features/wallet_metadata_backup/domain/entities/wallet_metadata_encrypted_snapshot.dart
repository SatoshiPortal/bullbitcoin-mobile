import 'dart:convert';

import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';

final class WalletMetadataEncryptedSnapshot {
  final WalletMetadataSnapshot plaintext;
  final String ciphertext;

  WalletMetadataEncryptedSnapshot({
    required this.plaintext,
    required this.ciphertext,
  }) {
    final bytes = base64.decode(ciphertext);
    if (bytes.length > WalletMetadataBackupLimits.maxCiphertextBytes) {
      throw ArgumentError.value(bytes.length, 'ciphertext');
    }
  }
}
