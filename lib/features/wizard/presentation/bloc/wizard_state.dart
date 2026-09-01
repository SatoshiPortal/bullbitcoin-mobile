part of 'wizard_bloc.dart';

@freezed
sealed class WizardState with _$WizardState {
  const factory WizardState({
    @Default(WizardChoices()) WizardChoices choices,
    @Default(false) bool finished,
    @Default(false) bool metadataBackupSaving,
    @Default(false) bool metadataBackupSaveFailed,
  }) = _WizardState;
  const WizardState._();
}
