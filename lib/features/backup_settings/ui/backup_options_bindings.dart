import 'package:backups/backups.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class BackupOptionsBindings {
  static BackupsFeature mount() => BackupsFeature.mount(
    copyOf: _copyOf,
    encryptedIcon: Image.asset(Assets.misc.encryptedVault.path, fit: .contain),
    physicalIcon: Image.asset(Assets.misc.physicalBackup.path, fit: .contain),
    onStartPhysical: (context) => context.pushNamed<void>(
      TestWalletBackupRoute.testPhysicalBackupFlow.name,
      extra: TestPhysicalBackupFlow.backup,
    ),
    onVerifyPhysical: (context) => context.pushNamed<void>(
      TestWalletBackupRoute.testPhysicalBackupFlow.name,
      extra: TestPhysicalBackupFlow.verify,
    ),
  );

  static BackupsCopy _copyOf(BuildContext context) {
    final loc = context.loc;
    return (
      backupTitle: loc.backupWalletTitle,
      testTitle: loc.testBackupTitle,
      importanceWarning: loc.backupWalletImportanceWarning,
      encrypted: (
        title: loc.backupWalletEncryptedVaultTitle,
        description: loc.backupWalletEncryptedVaultDescription,
        tag: loc.backupWalletEncryptedVaultTag,
      ),
      physical: (
        title: loc.backupWalletPhysicalBackupTitle,
        description: loc.backupWalletPhysicalBackupDescription,
        tag: loc.backupWalletPhysicalBackupTag,
      ),
      helpLabel: loc.backupWalletHowToDecide,
      helpTitle: loc.backupWalletHowToDecideBackupModalTitle,
      closeLabel: loc.closeDialogButton,
      losePhysical: loc.backupWalletHowToDecideBackupLosePhysical,
      encryptedVault: loc.backupWalletHowToDecideBackupEncryptedVault,
      physicalRecommendation:
          loc.backupWalletHowToDecideBackupPhysicalRecommendation,
      physicalRecommendationText:
          loc.backupWalletHowToDecideBackupPhysicalRecommendationText,
      encryptedRecommendation:
          loc.backupWalletHowToDecideBackupEncryptedRecommendation,
      encryptedRecommendationText:
          loc.backupWalletHowToDecideBackupEncryptedRecommendationText,
      moreInfo: loc.backupWalletHowToDecideBackupMoreInfo,
    );
  }
}
