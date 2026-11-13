import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Prevents an old onboarding choice from overriding a newer settings change.
class ClearPendingExchangeChoiceUsecase {
  const ClearPendingExchangeChoiceUsecase(this._repository);

  final WizardRepository _repository;

  Future<void> execute() async {
    final choices = await _repository.readPending();
    if (choices == null ||
        !choices.touched.contains(WizardField.exchangeAccess)) {
      return;
    }
    final remaining = Set<WizardField>.of(choices.touched)
      ..remove(WizardField.exchangeAccess);
    await _repository.savePending(
      WizardChoices(
        language: choices.language,
        themeMode: choices.themeMode,
        defaultCurrency: choices.defaultCurrency,
        reportingConsent: choices.reportingConsent,
        exchangeAccess: choices.exchangeAccess,
        touched: remaining,
      ),
    );
  }
}
