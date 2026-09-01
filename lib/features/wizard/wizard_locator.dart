import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:get_it/get_it.dart';

/// The wizard runs pre-locator (in `main()`) for the gating check and
/// the bloc itself, so most of its dependencies are wired manually
/// from `lib/main.dart` and `WizardApp`. The locator only exposes the
/// post-init facade used once the SQLite settings repository is available.
class WizardLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<WizardFacade>(() {
      final repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());
      final applyPendingChoices = ApplyPendingWizardChoicesUsecase(
        wizardRepository: repository,
        settingsRepository: locator<SettingsRepository>(),
        walletBackup: locator<WalletBackupFacade>(),
      );
      return WizardFacade(applyPendingChoices.execute);
    });
  }
}
