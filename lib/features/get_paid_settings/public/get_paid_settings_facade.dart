export 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_settings_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/publish_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';

/// Cross-feature contract for optional automated Get Paid backups.
///
/// Backup activation is independent from product activation. Publication is
/// best effort so a Bullnym failure can never fail wallet materialization.
class GetPaidSettingsFacade {
  final _GetPaidSettingsDependencies _dependencies;

  const GetPaidSettingsFacade({
    required GetGetPaidSettingsUsecase getSettings,
    required SetAutomatedBackupEnabledUsecase setAutomatedBackupEnabled,
    required PublishAutomatedKeychainBackupUsecase publishBackup,
  }) : _dependencies = (
         getSettings: getSettings,
         setAutomatedBackupEnabled: setAutomatedBackupEnabled,
         publishBackup: publishBackup,
       );

  Future<GetPaidSettings> getSettings() => _dependencies.getSettings.execute();

  Stream<GetPaidSettings> watchSettings() => _dependencies.getSettings.watch();

  Future<void> setAutomatedBackupEnabled(bool enabled) =>
      _dependencies.setAutomatedBackupEnabled.execute(enabled);

  Future<void> publishBackupSnapshotIfEnabled() async {
    try {
      await _dependencies.publishBackup.execute();
    } catch (error, stack) {
      log.warning(
        'Automated keychain backup failed',
        error: error,
        trace: stack,
      );
    }
  }
}

typedef _GetPaidSettingsDependencies = ({
  GetGetPaidSettingsUsecase getSettings,
  SetAutomatedBackupEnabledUsecase setAutomatedBackupEnabled,
  PublishAutomatedKeychainBackupUsecase publishBackup,
});
