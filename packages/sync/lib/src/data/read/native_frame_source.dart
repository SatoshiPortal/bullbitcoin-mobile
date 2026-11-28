import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/read_admission_port.dart';
import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/sync_failure.dart';
import '../../domain/wallet_key.dart';
import '../../domain/wallet_revision.dart';
import '../../domain/wallet_values.dart';
import '../wallet_projections.dart';
import '../write/datasources/native_store_errors.dart';
import 'wallet_frame_mapper.dart';
import 'wallet_snapshot_reader.dart';

/// Frames from the shared reader: hydration under its brief admission, then
/// mapping after the lease is released. A revision already mapped is reused,
/// whatever status it is published with.
final class NativeFrameSource implements CatalogueFrameSource {
  final WalletSnapshotReader _reader;
  final WalletCatalogPort _catalog;

  NativeFrameSource(this._reader, this._catalog);

  Future<Result<BigInt, SyncFailure>> loadBalance(
    WalletRevision expected,
    WalletCatalogPort catalog, {
    required bool Function() isCurrent,
    required Future<Result<ReadLease, SyncFailure>> Function(WalletKey)
    acquireExisting,
    Future<void> Function()? beforeHydration,
  }) => _reader.readBalance(
    expected,
    catalog,
    isCurrent: isCurrent,
    acquireExisting: acquireExisting,
    beforeHydration: beforeHydration,
    map: (wallet) async => switch (wallet) {
      final bdk.Wallet wallet => BigInt.from(wallet.balance().total.toSat()),
      final lwk.Wallet wallet => await liquidPolicyBalance(
        wallet,
        isCurrent: isCurrent,
      ),
      _ => throw StateError('Unsupported native wallet handle'),
    },
  );

  @override
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) => loadFrom(key, current, _catalog);

  @override
  Future<Result<LoadedFrame, SyncFailure>> loadFrom(
    WalletKey key,
    WalletFrame? current,
    WalletCatalogPort catalog,
  ) async {
    switch (await _reader.read(key, catalog)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final snapshot):
        final admitted = snapshot.admitted;
        if (current != null && current.revision == snapshot.revision) {
          // Same revision: only the status may change, never the data.
          return Ok((
            frame: current.stale == snapshot.stale
                ? current
                : WalletFrame(current.data, stale: snapshot.stale),
            admitted: admitted,
          ));
        }
        try {
          final data = switch (snapshot.wallet) {
            final bdk.Wallet wallet => bitcoinFrameData(
              wallet,
              snapshot.revision,
            ),
            final lwk.Wallet wallet => await liquidFrameData(
              wallet,
              snapshot.revision,
            ),
            _ => null,
          };
          if (data == null) return const Err(SyncInvalidCatalogFailure());
          return Ok((
            frame: WalletFrame(data, stale: snapshot.stale),
            admitted: admitted,
          ));
        } on Exception catch (error) {
          return Err(mappingFailure(error));
        }
    }
  }

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async {
    switch (await _reader.read(key, _catalog)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final snapshot):
        try {
          return switch (snapshot.wallet) {
            final bdk.Wallet wallet => Ok(
              bitcoinAddress(wallet, keychain, index),
            ),
            final lwk.Wallet wallet when keychain == Keychain.external => Ok(
              await liquidAddress(wallet, index),
            ),
            final lwk.Wallet _ => const Err(SyncUnsupportedNetworkFailure()),
            _ => const Err(SyncInvalidCatalogFailure()),
          };
        } on Exception catch (error) {
          return Err(mappingFailure(error));
        }
    }
  }
}

/// A native failure while mapping a hydrated wallet: repair only after LWK's
/// status conflict, storage otherwise.
SyncFailure mappingFailure(Exception error) => isLiquidStatusConflict(error)
    ? const SyncNeedsRepairFailure()
    : const SyncStorageFailure();
