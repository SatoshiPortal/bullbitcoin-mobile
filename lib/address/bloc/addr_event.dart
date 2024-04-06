part of 'addr_bloc.dart';

class AddressEvent {}

class LoadAddresses extends AddressEvent {
  final Wallet wallet;
  LoadAddresses({required this.wallet});
}

class SyncAddresss extends AddressEvent {
  final List<Tx> txs;
  final List<Address> oldAddresses;
  final Wallet wallet;
  SyncAddresss({required this.txs, required this.oldAddresses, required this.wallet});
}

class SelectAddress extends AddressEvent {
  final Address address;
  SelectAddress({required this.address});
}

class ChangeSelectedAddressKind extends AddressEvent {
  final AddressKind kind;
  ChangeSelectedAddressKind({required this.kind});
}
