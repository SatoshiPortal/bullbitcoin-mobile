import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';

enum WalletBackupFileFormat { encrypted, readable }

final class WalletBackupFile {
  static const maximumBytes = 1572864;
  final WalletBackupFileFormat format;
  final WalletBackupSnapshot snapshot;
  final DateTime createdAt;

  WalletBackupFile({
    required this.format,
    required this.snapshot,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc() {
    if (createdAt.millisecondsSinceEpoch < 0) {
      throw const FormatException('Invalid file export date');
    }
  }
}
