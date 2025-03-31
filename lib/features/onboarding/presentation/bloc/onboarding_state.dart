part of 'onboarding_bloc.dart';

@freezed
class OnboardingStepStatus with _$OnboardingStepStatus {
  const factory OnboardingStepStatus.none() = None;
  const factory OnboardingStepStatus.loading() = Loading;
  const factory OnboardingStepStatus.success() = Success;
  const factory OnboardingStepStatus.error(String error) = Error;
}

enum OnboardingStep { splash, create, recover }

@freezed
class VaultProvider with _$VaultProvider {
  const factory VaultProvider.googleDrive() = GoogleDrive;
  const factory VaultProvider.iCloud() = ICloud;
  const factory VaultProvider.fileSystem(String fileAsString) = FileSystem;
}

@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingStep.splash) OnboardingStep step,
    @Default({}) Map<int, String> validWords,
    @Default({}) Map<int, List<String>> hintWords,
    @Default(OnboardingStepStatus.none())
    OnboardingStepStatus onboardingStepStatus,
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default(BackupInfo.empty()) BackupInfo backupInfo,
  }) = _OnboardingState;
  const OnboardingState._();

  bool hasAllValidWords() =>
      validWords.length == 12 && onboardingStepStatus is! Loading;
}
