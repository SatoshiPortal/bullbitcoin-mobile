import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletBackupRecovery {
  final WalletInventoryRecovery wallets;
  final bool publicRecordsRestored;
  final bool metadataRestored;
  final WalletBackupFailure? failure;

  const WalletBackupRecovery({
    required this.wallets,
    required this.publicRecordsRestored,
    required this.metadataRestored,
    this.failure,
  });

  bool get complete =>
      wallets.complete &&
      publicRecordsRestored &&
      metadataRestored &&
      failure == null;
}
