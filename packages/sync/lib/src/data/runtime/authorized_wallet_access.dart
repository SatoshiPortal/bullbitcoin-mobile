import 'package:primitives/primitives.dart'
    show Err, NetworkCapabilities, NetworkCapability, Ok, Result;
import 'package:secrets/secrets.dart'
    show WalletInventory, WalletRegistrationNotFoundFailure;
import 'package:sync/sync.dart' as sync;

import 'wallet_native_runtime.dart';

/// Resolves an authorized inventory row before opening its native wallet.
///
/// Inventory membership is the permission boundary. A native row that is not
/// visible in the active inventory is never opened, and missing native state is
/// not confused with an absent authorized row.
final class AuthorizedWalletAccess {
  final WalletInventory inventory;
  final WalletNativeRuntime Function() runtime;

  const AuthorizedWalletAccess({
    required this.inventory,
    required this.runtime,
  });

  Future<sync.Wallet> open(String walletId) async {
    final key = switch (await inventory.readWallet(walletId)) {
      Ok(:final value) => sync.WalletKey(id: value.id, network: value.network),
      Err(failure: WalletRegistrationNotFoundFailure()) =>
        throw const sync.WalletSnapshotException(sync.SyncNotFoundFailure()),
      Err() => throw const sync.WalletSnapshotException(
        sync.SyncStorageFailure(),
      ),
    };
    if (!NetworkCapabilities.supports(
      key.network,
      NetworkCapability.softwareWallet,
    )) {
      throw const sync.WalletSnapshotException(
        sync.SyncUnsupportedNetworkFailure(),
      );
    }
    return _value(
      (await runtime().wallet(key)).mapErr(
        (failure) => failure is sync.SyncNotFoundFailure
            ? const sync.SyncInvalidCatalogFailure()
            : failure,
      ),
    );
  }

  static T _value<T>(Result<T, sync.SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw sync.WalletSnapshotException(failure),
  };
}
