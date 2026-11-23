import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletKey;

import 'address_view_failure.dart';

/// Resolves a route's wallet ID in the active foreground inventory.
final class ResolveAddressWalletUsecase {
  final WalletInventory _inventory;

  const ResolveAddressWalletUsecase(this._inventory);

  @useResult
  Future<Result<WalletKey, AddressViewFailure>> execute(String id) async {
    if (id.isEmpty) return const Err(AddressViewWalletNotFoundFailure());
    return switch (await _inventory.readWallet(id)) {
      Ok(:final value) => Ok(WalletKey(id: value.id, network: value.network)),
      Err(failure: WalletRegistrationNotFoundFailure()) => const Err(
        AddressViewWalletNotFoundFailure(),
      ),
      Err() => const Err(AddressViewAddressesUnavailableFailure()),
    };
  }
}
