import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';

enum WalletBackupFileFormat { encrypted, readable }

final class WalletBackupFile {
  static const maximumBytes = 1572864;
  final WalletBackupFileFormat format;
  final WalletBackupSnapshot snapshot;

  const WalletBackupFile({required this.format, required this.snapshot});
}
