import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';
import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservations.dart';

export 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

/// Read-only access to the application's static BIP85 reservation policy.
class Bip85RegistryFacade {
  const Bip85RegistryFacade();

  List<Bip85Reservation> get reservations => Bip85Reservations.all;

  Bip85Reservation get btcpayWalletSeed => Bip85Reservations.btcpayWalletSeed;

  Set<int> get reservedWalletSeedIndices => Set.unmodifiable(
    Bip85Reservations.all
        .where(
          (reservation) =>
              reservation.purpose == Bip85ReservationPurpose.walletSeed,
        )
        .map((reservation) => reservation.walletIndex),
  );

  Set<String> get reservedWalletSeedPaths => Set.unmodifiable(
    Bip85Reservations.all
        .where(
          (reservation) =>
              reservation.purpose == Bip85ReservationPurpose.walletSeed,
        )
        .map((reservation) => reservation.scope.exactPath),
  );

  Bip85Reservation? reservationById(String id) {
    for (final reservation in reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }
}
