import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

/// Vault imports only; this result never acknowledges full Data Backup recovery.
final class VaultBackupRecovery {
  final WalletBackupInspection inspection;
  final WalletInventoryRecovery wallets;
  final WalletBackupFailure? failure;
  const VaultBackupRecovery({
    required this.inspection,
    required this.wallets,
    this.failure,
  });

  bool get complete => wallets.complete && failure == null;
}
