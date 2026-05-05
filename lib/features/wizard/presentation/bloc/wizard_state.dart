part of 'wizard_bloc.dart';

@freezed
sealed class WizardState with _$WizardState {
  const factory WizardState({
    @Default(WizardChoices()) WizardChoices choices,
    @Default(false) bool finished,
  }) = _WizardState;
  const WizardState._();
}
