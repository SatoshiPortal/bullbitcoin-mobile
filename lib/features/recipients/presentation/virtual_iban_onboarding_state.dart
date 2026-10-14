part of 'virtual_iban_onboarding_cubit.dart';

enum VirtualIbanOnboardingStep { loading, intro, activating, active }

@freezed
abstract class VirtualIbanOnboardingState with _$VirtualIbanOnboardingState {
  const factory VirtualIbanOnboardingState({
    @Default(VirtualIbanOnboardingStep.loading) VirtualIbanOnboardingStep step,
    String? accountOwnerName,
    @Default(false) bool isCreating,
    RecipientsFailure? failure,
  }) = _VirtualIbanOnboardingState;
}
