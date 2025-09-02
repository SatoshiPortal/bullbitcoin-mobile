import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/choose_encrypted_vault_provider_screen.dart';
// import 'package:bb_mobile/features/test_wallet_backup/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/fetched_backup_info_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/test_physical_backup_screen.dart'
    show TestPhysicalBackupFlow;
import 'package:go_router/go_router.dart';

enum TestWalletBackupSubroute {
  chooseBackupTestProvider('choose-backup-test-provider'),
  testBackupInfo('test-backup-info'),
  testPhysicalBackup('test-physical-backup'),

  backupTestSuccess('backup-test-success');

  final String path;

  const TestWalletBackupSubroute(this.path);
}

class TestWalletBackupRouter {
  static final routes = [
    GoRoute(
      name: TestWalletBackupSubroute.chooseBackupTestProvider.name,
      path: TestWalletBackupSubroute.chooseBackupTestProvider.path,
      builder: (context, state) => const ChooseVaultProviderScreen(),
    ),
    GoRoute(
      name: TestWalletBackupSubroute.testBackupInfo.name,
      path: TestWalletBackupSubroute.testBackupInfo.path,
      builder: (context, state) {
        final bullBackup = state.extra! as EncryptedVault;
        return FetchedBackupInfoScreen(bullBackup: bullBackup);
      },
    ),
    GoRoute(
      path: TestWalletBackupSubroute.backupTestSuccess.path,
      name: TestWalletBackupSubroute.backupTestSuccess.name,
      builder: (context, state) {
        return const BackupTestSuccessScreen();
      },
    ),
    GoRoute(
      path: TestWalletBackupSubroute.testPhysicalBackup.path,
      name: TestWalletBackupSubroute.testPhysicalBackup.name,
      builder: (context, state) => const TestPhysicalBackupFlow(),
    ),
  ];
}
