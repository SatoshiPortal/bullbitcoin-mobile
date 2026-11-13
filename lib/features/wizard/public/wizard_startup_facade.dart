import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/data/wizard_install_classifier.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/classify_wizard_install_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/clear_pending_exchange_choice_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/read_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';

export 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';

class WizardStartupFacade {
  Future<Result<bool, WizardInstallFailure>> shouldRunWizard() =>
      ClassifyWizardInstallUsecase(WizardInstallClassifier()).execute();

  /// Clear a stale onboarding choice after a newer settings change succeeds.
  /// Propagates storage failures so callers can avoid reporting full success.
  Future<void> clearPendingExchangeChoice() =>
      ClearPendingExchangeChoiceUsecase(
        WizardRepositoryImpl(WizardLocalDatasourceImpl()),
      ).execute();

  Future<bool?> readReportingConsent() async {
    final repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());
    final pending = await ReadPendingWizardChoicesUsecase(
      repository: repository,
    ).execute();
    return pending?.reportingConsent;
  }
}

class WizardStartupException implements Exception {
  const WizardStartupException(this.failure);

  final WizardInstallFailure failure;
}
