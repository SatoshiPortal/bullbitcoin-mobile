part of 'address_view_bloc.dart';

@freezed
sealed class AddressViewState with _$AddressViewState {
  const factory AddressViewState({
    @Default([]) List<WalletAddress> receiveAddresses,
    @Default([]) List<WalletAddress> changeAddresses,
    @Default(false) bool isLoading,
    @Default(false) bool hasReachedEndOfReceiveAddresses,
    @Default(false) bool hasReachedEndOfChangeAddresses,
    WalletError? error,
  }) = _AddressViewState;
  const AddressViewState._();
}
