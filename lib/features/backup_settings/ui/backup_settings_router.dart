import 'package:bb_mobile/features/backup_settings/ui/screens/backup_options_screen.dart';
import 'package:go_router/go_router.dart';

enum BackupSettingsFlow { backup, test }

class BackupOptionsArgs {
  final BackupSettingsFlow flow;
  final bool hasPhysicalBackup;
  final bool hasEncryptedBackup;

  const BackupOptionsArgs({
    required this.flow,
    required this.hasPhysicalBackup,
    required this.hasEncryptedBackup,
  });
}

enum BackupSettingsSubroute {
  backupOptions('backup-options');

  final String path;

  const BackupSettingsSubroute(this.path);
}

class BackupSettingsSettingsRouter {
  static final route = GoRoute(
    name: BackupSettingsSubroute.backupOptions.name,
    path: BackupSettingsSubroute.backupOptions.path,
    builder: (context, state) {
      final extra = state.extra;
      return switch (extra) {
        BackupOptionsArgs() => BackupOptionsScreen(
          flow: extra.flow,
          hasPhysicalBackup: extra.hasPhysicalBackup,
          hasEncryptedBackup: extra.hasEncryptedBackup,
        ),
        _ => BackupOptionsScreen(
          flow: extra as BackupSettingsFlow? ?? BackupSettingsFlow.backup,
        ),
      };
    },
  );
}
