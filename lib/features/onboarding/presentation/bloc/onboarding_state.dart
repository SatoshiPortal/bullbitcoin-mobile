part of 'onboarding_bloc.dart';

@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState.initial() = OnboardingInitial;
  const factory OnboardingState.walletCreationInProgress() =
      OnboardingWalletCreationInProgress;
  const factory OnboardingState.success() = OnboardingSuccess;
  const factory OnboardingState.failure(Object? e) = OnboardingFailure;
}
