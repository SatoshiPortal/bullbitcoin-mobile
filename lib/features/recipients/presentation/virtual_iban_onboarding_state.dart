part of 'virtual_iban_onboarding_cubit.dart';

@freezed
abstract class VirtualIbanOnboardingState with _$VirtualIbanOnboardingState {
  const factory VirtualIbanOnboardingState({
    VirtualIbanStatus? status,
    @Default(false) bool isLoading,
    @Default(false) bool isCreating,
    @Default(false) bool isNameConfirmed,
    RecipientsFailure? failure,
  }) = _VirtualIbanOnboardingState;
}
