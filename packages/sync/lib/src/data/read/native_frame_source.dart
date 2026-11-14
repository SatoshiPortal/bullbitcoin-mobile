import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/sync_failure.dart';
import '../../domain/wallet_key.dart';
import '../../domain/wallet_values.dart';
import '../wallet_projections.dart';
import 'wallet_frame_mapper.dart';
import 'wallet_snapshot_reader.dart';

/// Frames from the shared reader: hydration under its brief admission, then
/// mapping after the lease is released. A revision already mapped is reused.
final class NativeFrameSource implements FrameSource {
  final WalletSnapshotReader _reader;
  final WalletCatalogPort _catalog;

  NativeFrameSource(this._reader, this._catalog);

  @override
  Future<Result<WalletFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async {
    switch (await _reader.read(key, _catalog)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final snapshot):
        if (current != null &&
            current.revision == snapshot.revision &&
            current.stale == snapshot.stale) {
          return Ok(current);
        }
        try {
          return switch (snapshot.wallet) {
            final bdk.Wallet wallet => Ok(
              bitcoinFrame(wallet, snapshot.revision, stale: snapshot.stale),
            ),
            final lwk.Wallet wallet => Ok(
              await liquidFrame(
                wallet,
                snapshot.revision,
                stale: snapshot.stale,
              ),
            ),
            _ => const Err(SyncInvalidCatalogFailure()),
          };
        } on Exception {
          return const Err(SyncNeedsRepairFailure());
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
        } on Exception {
          return const Err(SyncNeedsRepairFailure());
        }
    }
  }
}
