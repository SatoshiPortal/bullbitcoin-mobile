part of 'address_view_bloc.dart';

@freezed
sealed class AddressViewEvent with _$AddressViewEvent {
  const factory AddressViewEvent.loadInitialAddresses() =
      AddressViewInitialAddressesLoaded;
  const factory AddressViewEvent.loadMoreReceiveAddresses() =
      AddressViewMoreReceiveAddressesLoaded;
  const factory AddressViewEvent.loadMoreChangeAddresses() =
      AddressViewMoreChangeAddressesLoaded;
}
