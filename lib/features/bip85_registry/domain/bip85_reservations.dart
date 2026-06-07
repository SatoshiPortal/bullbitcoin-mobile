import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

class Bip85Reservations {
  const Bip85Reservations._();

  static final btcpayWalletSeed = Bip85Reservation(
    id: 'btcpay_wallet_seed',
    deterministicAlias: 'BTCPay',
    owner: Bip85ReservationOwner.btcpay,
    purpose: Bip85ReservationPurpose.walletSeed,
    application: const Bip85ApplicationSpec(number: 39),
    segments: const [
      Bip85PathSegment(name: 'language', value: 0),
      Bip85PathSegment(name: 'words', value: 12),
      Bip85PathSegment(name: 'index', value: 100),
    ],
  );

  static final List<Bip85Reservation> all = List.unmodifiable([
    btcpayWalletSeed,
  ]);
}
