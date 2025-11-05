import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/test_physical_backup_screen.dart'
    show TestPhysicalBackupFlow;
import 'package:go_router/go_router.dart';

enum TestWalletBackupSubroute {
  testPhysicalBackup('test-physical-backup'),
  backupTestSuccess('backup-test-success');

  final String path;

  const TestWalletBackupSubroute(this.path);
}

class TestWalletBackupRouter {
  static final routes = [
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
