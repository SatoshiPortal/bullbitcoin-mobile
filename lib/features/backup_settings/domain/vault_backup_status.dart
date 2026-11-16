import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

final class VaultBackupStatus {
  final BullVaultRecord record;
  final WalletBackupControl control;
  final bool canRevealWords;
  final String recoveryPackageSource;

  const VaultBackupStatus({
    required this.record,
    required this.control,
    required this.canRevealWords,
    required this.recoveryPackageSource,
  });

  VaultBackupStatus withRecord(BullVaultRecord updated) => VaultBackupStatus(
    record: updated,
    control: control,
    canRevealWords: canRevealWords,
    recoveryPackageSource: recoveryPackageSource,
  );
}

final class VaultBackupCheck {
  final BullVaultRecord record;
  final WalletBackupInspection inspection;

  const VaultBackupCheck(this.record, this.inspection);
}
