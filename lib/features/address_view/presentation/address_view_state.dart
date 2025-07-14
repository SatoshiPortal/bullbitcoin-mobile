part of 'address_view_bloc.dart';

@freezed
sealed class AddressViewState with _$AddressViewState {
  const factory AddressViewState({
    @Default([]) List<WalletAddress> receiveAddresses,
    @Default([]) List<WalletAddress> changeAddresses,
    @Default(false) bool isLoading,
    WalletError? error,
  }) = _AddressViewState;
  const AddressViewState._();

  bool get hasReachedEndOfReceiveAddresses =>
      receiveAddresses.isNotEmpty && receiveAddresses.last.index == 0;
  bool get hasReachedEndOfChangeAddresses =>
      changeAddresses.isNotEmpty && changeAddresses.last.index == 0;
}
