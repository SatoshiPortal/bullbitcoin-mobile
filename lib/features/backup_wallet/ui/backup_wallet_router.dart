import 'package:bb_mobile/features/backup_wallet/ui/screens/backup_check_list_screen.dart';
import 'package:bb_mobile/features/backup_wallet/ui/screens/backup_success_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupWalletSubroute {
  physical('backup-physical'),
  physicalCheckList('backup-physical-checklist'),
  backupSuccess('backup-success');

  final String path;

  const BackupWalletSubroute(this.path);
}

class BackupWalletRouter {
  static final routes = [
    GoRoute(
      path: BackupWalletSubroute.backupSuccess.path,
      name: BackupWalletSubroute.backupSuccess.name,
      builder: (context, state) {
        return const BackupSuccessScreen();
      },
    ),
    GoRoute(
      path: BackupWalletSubroute.physicalCheckList.path,
      name: BackupWalletSubroute.physicalCheckList.name,
      builder: (context, state) {
        return const BackCheckListScreen();
      },
    ),
  ];
}
