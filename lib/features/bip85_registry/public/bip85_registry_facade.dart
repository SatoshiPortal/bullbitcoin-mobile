import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';
import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservations.dart';

export 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

/// Read-only access to the application's static BIP85 reservation policy.
class Bip85RegistryFacade {
  const Bip85RegistryFacade();

  List<Bip85Reservation> get reservations => Bip85Reservations.all;

  Bip85WalletSeedReservation get btcpayWalletSeed =>
      Bip85Reservations.btcpayWalletSeed;

  // Registry-driven exclusion sets for the BIP85 next-index allocator and the
  // dev derivation screen: every reserved wallet-seed index/path is a product
  // spend seed that must never be allocated as a "next" dev derivation nor have
  // its entropy re-derived and exposed. Derived from the reservation list, so a
  // new wallet-seed reservation is covered automatically (KI-1/KI-2).
  Set<int> get reservedWalletSeedIndices => Set.unmodifiable(
    Bip85Reservations.all.whereType<Bip85WalletSeedReservation>().map(
      (reservation) => reservation.walletIndex,
    ),
  );

  Set<String> get reservedWalletSeedPaths => Set.unmodifiable(
    Bip85Reservations.all.whereType<Bip85WalletSeedReservation>().map(
      (reservation) => reservation.scope.exactPath,
    ),
  );

  Bip85Reservation? reservationById(String id) {
    for (final reservation in reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }
}
