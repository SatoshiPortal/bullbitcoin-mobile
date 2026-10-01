part of 'fr_payee_activation_cubit.dart';

@freezed
abstract class FrPayeeActivationState with _$FrPayeeActivationState {
  const factory FrPayeeActivationState({
    required RecipientViewModel recipient,
    @Default(false) bool isActivating,
    @Default(false) bool isActive,
    @Default(false) bool initialWaitTimedOut,
    RecipientsFailure? failure,
  }) = _FrPayeeActivationState;
}
