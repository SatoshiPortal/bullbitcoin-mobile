import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// A fresh install: the app's freeze table exists and is empty.
final class NoLegacyFreezes implements LegacyFreezeSourcePort {
  const NoLegacyFreezes();

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async =>
      const Ok([]);
}

/// A catalog without wallets, for a [Sync] used only for its freezes.
final class NoCatalog implements WalletCatalogPort {
  const NoCatalog();

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);
}

final class NoReservedAddresses implements ReservedAddressPort {
  const NoReservedAddresses();

  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

/// A foreground [Sync] in [documentsDirectory] whose freeze import is an
/// empty app table.
Sync freezesOnlySync(String documentsDirectory) => Sync.openForeground(
  documentsDirectory: documentsDirectory,
  catalog: const NoCatalog(),
  reservedAddresses: const NoReservedAddresses(),
  legacyFreezes: const NoLegacyFreezes(),
  inputReservations: NoInputReservations(),
);

/// No reservation held: every input is free of external sessions.
final class NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}
