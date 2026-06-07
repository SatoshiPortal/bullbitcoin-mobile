import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';

class KeychainManifestReservationSupport {
  const KeychainManifestReservationSupport._();

  static bool supportsV1WalletManifestFile(Bip85Reservation reservation) {
    return reservation.id == 'btcpay_wallet_seed' &&
        reservation.purpose == Bip85ReservationPurpose.walletSeed;
  }
}
