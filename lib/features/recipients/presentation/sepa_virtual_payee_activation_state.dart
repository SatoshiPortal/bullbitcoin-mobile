part of 'sepa_virtual_payee_activation_cubit.dart';

@freezed
abstract class SepaVirtualPayeeActivationState
    with _$SepaVirtualPayeeActivationState {
  const factory SepaVirtualPayeeActivationState({
    /// `null` until the first status is known.
    SepaVirtualPayeeStatus? status,
    @Default(false) bool isWatching,
    RecipientsFailure? failure,
  }) = _SepaVirtualPayeeActivationState;
  const SepaVirtualPayeeActivationState._();

  bool get isActive => status?.isActive ?? false;
}
