import 'package:bb_mobile/features/get_paid_settings/domain/usecases/delete_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_settings_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/publish_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

final class GetPaidSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<GetGetPaidSettingsUsecase>(
      () => GetGetPaidSettingsUsecase(locator<KeychainManifestFacade>()),
    );
    locator.registerFactory<SetAutomatedBackupEnabledUsecase>(
      () => SetAutomatedBackupEnabledUsecase(locator<KeychainManifestFacade>()),
    );
    locator.registerFactory<PublishAutomatedKeychainBackupUsecase>(
      () => PublishAutomatedKeychainBackupUsecase(
        locator<KeychainManifestFacade>(),
      ),
    );
    locator.registerFactory<DeleteAutomatedKeychainBackupUsecase>(
      () => DeleteAutomatedKeychainBackupUsecase(
        locator<KeychainManifestFacade>(),
      ),
    );
    locator.registerFactory<GetPaidSettingsCubit>(
      () => GetPaidSettingsCubit(
        getSettings: locator<GetGetPaidSettingsUsecase>(),
        setEnabled: locator<SetAutomatedBackupEnabledUsecase>(),
        publish: locator<PublishAutomatedKeychainBackupUsecase>(),
        deleteBackup: locator<DeleteAutomatedKeychainBackupUsecase>(),
      ),
    );
  }
}
