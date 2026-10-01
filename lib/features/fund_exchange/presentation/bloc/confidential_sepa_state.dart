part of 'confidential_sepa_cubit.dart';

@freezed
abstract class ConfidentialSepaState with _$ConfidentialSepaState {
  const factory ConfidentialSepaState({
    VirtualIbanStatus? status,
    @Default(false) bool isLoading,
    @Default(false) bool isCreating,
    @Default(false) bool isNameConfirmed,
    FundExchangePresentationError? error,
  }) = _ConfidentialSepaState;
}
