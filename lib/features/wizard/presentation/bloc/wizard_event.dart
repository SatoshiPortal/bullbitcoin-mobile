part of 'wizard_bloc.dart';

@freezed
sealed class WizardEvent with _$WizardEvent {
  const factory WizardEvent.themePicked(AppThemeMode mode) = _WizardThemePicked;
  const factory WizardEvent.languagePicked(Language language) =
      _WizardLanguagePicked;
  const factory WizardEvent.currencyPicked(String code) = _WizardCurrencyPicked;
  const factory WizardEvent.consentPicked(bool consent) = _WizardConsentPicked;
  const factory WizardEvent.themeDetected(AppThemeMode mode) =
      _WizardThemeDetected;
  const factory WizardEvent.languageDetected(Language language) =
      _WizardLanguageDetected;
  const factory WizardEvent.completed() = _WizardCompleted;
  const WizardEvent._();
}
