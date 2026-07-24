part of 'onboarding_bloc.dart';

enum OnboardingStepStatus { none, loading, success, error }

enum OnboardingStep { splash, create, recover }

@freezed
sealed class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingStep.splash) OnboardingStep step,
    @Default(OnboardingStepStatus.none)
    OnboardingStepStatus onboardingStepStatus,
    @Default('') String statusError,
    @Default(false) bool transitioning,
    // The three fields below carry a mnemonic recovery attempt across the
    // CBF birthday-picker pause — see
    // `OnboardingBloc._onRecoverWalletClicked`/`_onBitcoinBirthdayResolved`.
    // `OnboardingPhysicalRecovery`'s `BlocListener` shows
    // `WalletBirthdayPicker` when [needsBitcoinBirthdaySelection] turns
    // true, using [pendingRecoveryIsTestnet] for the picker's genesis
    // default, then dispatches `OnboardingBitcoinBirthdayResolved` with the
    // result. Never set for a freshly generated wallet — only a mnemonic
    // recovery that opted into compact block filters ever reaches this.
    @Default(false) bool needsBitcoinBirthdaySelection,
    RecoveryMnemonic? pendingRecoveryMnemonic,
    @Default(false) bool pendingRecoveryIsTestnet,
  }) = _OnboardingState;
  const OnboardingState._();

  bool get loadingCreate =>
      step == OnboardingStep.create ||
      onboardingStepStatus == OnboardingStepStatus.loading;

  bool get isSuccess => onboardingStepStatus == OnboardingStepStatus.success;

  bool get isCreation => step == OnboardingStep.create;

  bool get isRecovery => step == OnboardingStep.recover;
}
