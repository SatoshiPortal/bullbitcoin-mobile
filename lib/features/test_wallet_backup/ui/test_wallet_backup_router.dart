import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/available_google_backups_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/fetched_backup_info_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/test_physical_backup_screen.dart'
    show TestPhysicalBackupFlow;
import 'package:go_router/go_router.dart';

enum TestWalletBackupSubroute {
  chooseBackupTestProvider('choose-backup-test-provider'),
  selectBackupForTest('select-backup-for-test'),
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
      name: TestWalletBackupSubroute.selectBackupForTest.name,
      path: TestWalletBackupSubroute.selectBackupForTest.path,
      builder: (context, state) {
        final backups =
            state.extra != null
                ? state.extra! as List<DriveFile>
                : <DriveFile>[];
        return AvailableGoogleBackupsScreen(backups: backups);
      },
    ),
    GoRoute(
      name: TestWalletBackupSubroute.testBackupInfo.name,
      path: TestWalletBackupSubroute.testBackupInfo.path,
      builder: (context, state) {
        final backupFileId = state.extra! as String;
        return FetchedBackupInfoScreen(backupFileId: backupFileId);
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
