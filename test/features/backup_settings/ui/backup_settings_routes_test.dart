import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('wallet recovery and data backup are peer settings routes', () {
    final routes = SettingsRouter.route.routes.whereType<GoRoute>();
    final recovery = routes.singleWhere(
      (route) => route.name == SettingsRoute.walletRecoverySettings.name,
    );
    final data = routes.singleWhere(
      (route) => route.name == SettingsRoute.dataBackupSettings.name,
    );

    expect(recovery.path, SettingsRoute.walletRecoverySettings.path);
    expect(data.path, SettingsRoute.dataBackupSettings.path);
    expect(
      recovery.routes.whereType<GoRoute>().map((route) => route.name),
      contains(BackupSettingsSubroute.backupOptions.name),
    );
    expect(
      data.routes.whereType<GoRoute>().map((route) => route.name),
      containsAll([
        BackupSettingsSubroute.walletManifest.name,
        BackupSettingsSubroute.walletMetadata.name,
      ]),
    );
  });
}
