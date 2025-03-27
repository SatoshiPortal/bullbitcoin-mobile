import 'package:bb_mobile/features/backup_wallet/ui/screens/backup_options_screen.dart';
import 'package:bb_mobile/features/recover_wallet/ui/screens/recover_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsSubroute {
  backupOptions('backup-options'),
  recoverOptions('recover-options');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final routes = [
    GoRoute(
      name: BackupSettingsSubroute.backupOptions.name,
      path: BackupSettingsSubroute.backupOptions.path,
      builder: (context, state) => const BackupOptionsScreen(),
    ),
    GoRoute(
      name: BackupSettingsSubroute.recoverOptions.name,
      path: BackupSettingsSubroute.recoverOptions.path,
      builder: (context, state) => RecoverOptionsScreen(
        fromOnboarding: (state.extra as bool?) ?? false,
      ),
    ),
  ];
}
