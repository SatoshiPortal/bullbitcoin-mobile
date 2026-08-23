import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';
import 'package:bb_mobile/features/bip85_registry/domain/bip85_reservations.dart';

export 'package:bb_mobile/features/bip85_registry/domain/bip85_reservation.dart';

class Bip85RegistryFacade {
  const Bip85RegistryFacade();

  List<Bip85Reservation> get reservations => Bip85Reservations.all;
  Bip85Reservation get btcpayWalletSeed => Bip85Reservations.btcpayWalletSeed;
  Bip85Reservation get lightningAddressWalletSeed =>
      Bip85Reservations.lightningAddressWalletSeed;
  Bip85Reservation get paymentPageWalletSeed =>
      Bip85Reservations.paymentPageWalletSeed;
  Bip85Reservation get pointOfSaleWalletSeed => Bip85Reservations.posWalletSeed;

  Set<int> get reservedWalletSeedIndices => Set.unmodifiable(
    reservations
        .where((item) => item.isWalletSeed)
        .map((item) => item.walletIndex),
  );
  Set<String> get reservedWalletSeedPaths => Set.unmodifiable(
    reservations.where((item) => item.isWalletSeed).map((item) => item.path),
  );

  int get nostrApplicationNumber => Bip85Reservations.nostrApplicationNumber;
  String get nostrUserKeyReservationId =>
      Bip85Reservations.nostrUserKeyReservationId;
  int get nostrUserKeyApplication => nostrApplicationNumber;
  int get nostrUserIdentityStart => Bip85Reservations.nostrUserIdentityStart;
  int get nostrUserIdentityEnd => Bip85Reservations.nostrUserIdentityEnd;
  int get nostrUserAccount => Bip85Reservations.nostrUserAccount;
  int get nostrAppReservedIdentityStart =>
      Bip85Reservations.nostrAppReservedIdentityStart;
  int get nostrAppReservedIdentityEnd =>
      Bip85Reservations.nostrAppReservedIdentityEnd;

  bool isNostrAppReservedIdentity(int identity) =>
      identity >= nostrAppReservedIdentityStart &&
      identity <= nostrAppReservedIdentityEnd;

  String nostrUserKeyPath(int identity) {
    if (identity < nostrUserIdentityStart ||
        identity > nostrUserIdentityEnd ||
        isNostrAppReservedIdentity(identity)) {
      throw ArgumentError.value(identity, 'identity');
    }
    return "$nostrUserKeyApplication'/$identity'/$nostrUserAccount'";
  }

  int? nostrUserKeyIdentity(String path) {
    final parts = path.trim().split('/');
    if (parts.length != 3 ||
        parts.first != "$nostrUserKeyApplication'" ||
        parts.last != "$nostrUserAccount'") {
      return null;
    }
    final middle = parts[1];
    final identity = middle.endsWith("'")
        ? int.tryParse(middle.substring(0, middle.length - 1))
        : null;
    return identity != null &&
            identity >= nostrUserIdentityStart &&
            identity <= nostrUserIdentityEnd &&
            !isNostrAppReservedIdentity(identity)
        ? identity
        : null;
  }

  bool isNostrUserKeyPath(String path) {
    final identity = nostrUserKeyIdentity(path);
    return identity != null && nostrUserKeyPath(identity) == path.trim();
  }

  Bip85Reservation? reservationById(String id) =>
      reservations.where((item) => item.id == id).firstOrNull;

  Bip85Reservation? reservationByExactPath(String path) => reservations
      .where((item) => item.matchesExactPath(path.trim()))
      .firstOrNull;
}
