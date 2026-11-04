/// Host-owned reservation policy applied under the wallet source session.
abstract interface class WalletAddressReservationPort {
  Future<bool> isReserved(String address);
}
