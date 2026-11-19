part of 'wizard_bloc.dart';

@freezed
sealed class WizardState with _$WizardState {
  const factory WizardState({
    @Default(WizardChoices()) WizardChoices choices,
    @Default(false) bool finished,
    // Read from the system, never staged: the system keeps the answer.
    @Default(false) bool notificationsAllowed,
    @Default(false) bool notificationsRefused,
  }) = _WizardState;
  const WizardState._();
}
