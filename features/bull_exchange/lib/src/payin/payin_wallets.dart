import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

abstract interface class PayinWallets {
  Future<BitcoinSpendStatus> eligibility(WalletKey key);
  Future<Result<String, SyncFailure>> addressAt(WalletKey key, int index);
  Future<Result<List<Coin>, SyncFailure>> coins(WalletKey key);
}

final class InventoryPayinWallets implements PayinWallets {
  final WalletInventory _inventory;
  final WalletNativeRuntime _native;

  const InventoryPayinWallets(this._inventory, this._native);

  Future<WalletKey?> _localKey(String id) async =>
      switch (await _inventory.readWallet(id)) {
        Ok(
          value: WalletRegistration(
            :final id,
            :final network,
            signer: WalletSigner.local,
          ),
        ) =>
          WalletKey(id: id, network: network),
        _ => null,
      };

  @override
  Future<BitcoinSpendStatus> eligibility(WalletKey key) async {
    if (await _localKey(key.id) != key) return BitcoinSpendStatus.unavailable;
    if (key.network is LiquidNetwork) return BitcoinSpendStatus.ready;
    return switch (await _native.spendStatus(key)) {
      Ok(:final value) => value,
      Err(failure: SyncBusyFailure()) => BitcoinSpendStatus.busy,
      Err() => BitcoinSpendStatus.unavailable,
    };
  }

  @override
  Future<Result<String, SyncFailure>> addressAt(
    WalletKey key,
    int index,
  ) async {
    if (await _localKey(key.id) != key) return const Err(SyncNotFoundFailure());
    switch (await _native.wallet(key)) {
      case Ok(:final value):
        return readPayinAddress(value.addresses.at(index).watch());
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<List<Coin>, SyncFailure>> coins(WalletKey key) async {
    if (await _localKey(key.id) != key) return const Err(SyncNotFoundFailure());
    switch (await _native.wallet(key)) {
      case Ok(:final value):
        return (await value.unspent()).map((coins) => coins.toList());
      case Err(:final failure):
        return Err(failure);
    }
  }
}

Future<Result<String, SyncFailure>> readPayinAddress(
  Stream<WalletAddressAt> publications,
) async {
  final WalletAddressAt derived;
  try {
    derived = await publications.firstWhere(
      (value) => value.status != ValueStatus.notLoaded,
      orElse: () => const WalletAddressAt.closed(),
    );
  } on SyncFailure catch (failure) {
    return Err(failure);
  } on Object {
    // Dart streams can emit any object as an error. Keep foreign details out.
    return const Err(SyncStorageFailure());
  }
  if (derived.status == ValueStatus.closed) {
    return const Err(SyncClosedFailure());
  }
  return derived.latest.map((address) => address.address);
}
