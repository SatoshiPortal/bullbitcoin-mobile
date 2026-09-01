import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';

enum WalletBackupFileProtection { encrypted, unencrypted }

final class WalletBackupExport {
  static const maximumFileBytes = WalletBackupCiphertext.maximumEncodedLength;

  final String suggestedFilename;
  final List<int> _bytes;

  WalletBackupExport({
    required this.suggestedFilename,
    required List<int> bytes,
  }) : _bytes = List<int>.unmodifiable(bytes) {
    if (suggestedFilename.trim().isEmpty ||
        bytes.isEmpty ||
        bytes.length > maximumFileBytes) {
      throw ArgumentError('Wallet backup export is invalid');
    }
  }

  Uint8List copyBytes() => Uint8List.fromList(_bytes);
}
