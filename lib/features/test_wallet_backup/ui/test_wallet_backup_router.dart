import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
// import 'package:bb_mobile/features/test_wallet_backup/ui/screens/choose_encrypted_vault_provider_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/fetched_backup_info_screen.dart';
import 'package:go_router/go_router.dart';

enum TestWalletBackupSubroute {
  // chooseBackupTestProvider('choose-backup-test-provider'),
  testBackupInfo('test-backup-info'),
  //TODO: add physical backup subroutes
  // physical('backup-physical'),
  backupTestSuccess('backup-test-success'),
  ;

  final String path;

  const TestWalletBackupSubroute(this.path);
}

class TestWalletBackupRouter {
  static final routes = [
    // GoRoute(
    //   name: TestWalletBackupSubroute.chooseBackupTestProvider.name,
    //   path: TestWalletBackupSubroute.chooseBackupTestProvider.path,
    //   builder: (context, state) => const ChooseVaultProviderScreen(),
    // ),
    GoRoute(
      name: TestWalletBackupSubroute.testBackupInfo.name,
      path: TestWalletBackupSubroute.testBackupInfo.path,
      builder: (context, state) {
        final backupInfo = state.extra! as BackupInfo;
        return FetchedBackupInfoScreen(
          encryptedInfo: backupInfo,
        );
      },
    ),
    GoRoute(
      path: TestWalletBackupSubroute.backupTestSuccess.path,
      name: TestWalletBackupSubroute.backupTestSuccess.name,
      builder: (context, state) {
        return const BackupTestSuccessScreen();
      },
    ),
  ];
}
