part of 'onboarding_bloc.dart';

enum OnboardingStep { splash, createSucess, recoveryWords, recoverySuccess }

@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    // required bool initLoading,
    @Default(OnboardingStep.splash) OnboardingStep step,
    @Default({}) Map<int, String> validWords,
    @Default({}) Map<int, List<String>> hintWords,
    @Default(false) bool creating,
    Object? error,
  }) = _OnboardingState;
  const OnboardingState._();

  bool creatingOnSplash() => step == OnboardingStep.splash && creating;

  bool hasAllValidWords() => validWords.length == 12 && !creating;
}
