import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/answer_permissions_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/take_permissions_intro_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/permissions_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:notifications/notifications.dart';

/// The wizard runs pre-locator (during startup) for the gating check and
/// the bloc itself, so most of its dependencies are wired manually
/// from `lib/startup_wizard.dart` and `WizardApp`. The locator only exposes the
/// post-init flush usecase that `Bull.init` calls once the SQLite
/// settings repository is available.
class WizardLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<WizardLocalDatasource>(
      WizardLocalDatasourceImpl.new,
    );
    locator.registerLazySingleton<WizardRepository>(
      () => WizardRepositoryImpl(locator<WizardLocalDatasource>()),
    );
    locator.registerFactory<ApplyPendingWizardChoicesUsecase>(
      () => ApplyPendingWizardChoicesUsecase(
        wizardRepository: locator<WizardRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<TakePermissionsIntroUsecase>(
      () => TakePermissionsIntroUsecase(
        repository: locator<WizardRepository>(),
        permissions: locator<NotificationPermissionsFacade>(),
      ),
    );
    locator.registerFactory<PermissionsCubit>(
      () => PermissionsCubit(
        answer: AnswerPermissionsUsecase(
          permissions: locator<NotificationPermissionsFacade>(),
          repository: locator<WizardRepository>(),
        ),
      ),
    );
  }
}
