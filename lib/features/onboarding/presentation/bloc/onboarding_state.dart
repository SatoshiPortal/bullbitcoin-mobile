part of 'onboarding_bloc.dart';

enum OnboardingStepStatus { none, loading, success, error }

enum OnboardingStep { splash, create, recover }

@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingStep.splash) OnboardingStep step,
    @Default(OnboardingStepStatus.none)
    OnboardingStepStatus onboardingStepStatus,
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default(BackupInfo.empty()) BackupInfo backupInfo,
    @Default('') String statusError,
    @Default(false) bool transitioning,
  }) = _OnboardingState;
  const OnboardingState._();

  bool get loadingCreate =>
      step == OnboardingStep.create ||
      onboardingStepStatus == OnboardingStepStatus.loading;

  bool get isSuccess => onboardingStepStatus == OnboardingStepStatus.success;

  bool get isCreation => step == OnboardingStep.create;

  bool get isRecovery => step == OnboardingStep.recover;
}
