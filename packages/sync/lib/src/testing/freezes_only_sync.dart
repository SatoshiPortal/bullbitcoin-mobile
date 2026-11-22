import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'test_wallets.dart' show MemoryFreezeStore;

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

/// A foreground [Sync] in [documentsDirectory] over [freezes], an empty
/// in-memory store by default.
Sync freezesOnlySync(String documentsDirectory, {FreezeStorePort? freezes}) =>
    Sync.foreground(
      documentsDirectory: documentsDirectory,
      catalog: const NoCatalog(),
      reservedAddresses: const NoReservedAddresses(),
      freezes: freezes ?? MemoryFreezeStore(),
      inputReservations: NoInputReservations(),
      connections: const NoConnections(),
    );

/// No reservation held: every input is free of external sessions.
final class NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

/// No server: every operation fails to connect, nothing is sent.
final class NoConnections implements WalletConnectionPort {
  const NoConnections();

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async => const Err(SyncConnectionFailure());
}
