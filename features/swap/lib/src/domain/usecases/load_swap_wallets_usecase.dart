import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:signers/storage.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import '../entities/swap_wallet.dart';

class LoadSwapWalletsUsecase {
  final WalletInventory inventory;
  final WalletNativeRuntime sync;
  final SignerDevices Function() signerDevices;

  const LoadSwapWalletsUsecase(this.inventory, this.sync, this.signerDevices);

  Future<Result<List<SwapWallet>, SwapFailure>> execute(
    NetworkEnv environment,
  ) async {
    final List<Network> networks = switch (environment) {
      NetworkEnv.mainnet => [BitcoinNetwork.mainnet, LiquidNetwork.mainnet],
      NetworkEnv.testnet => [BitcoinNetwork.testnet, LiquidNetwork.testnet],
      NetworkEnv.regtest => [BitcoinNetwork.regtest, LiquidNetwork.regtest],
      NetworkEnv.signet => [BitcoinNetwork.signet],
    };
    final registrations = <WalletRegistration>[];
    for (final network in networks) {
      switch (await inventory.walletsForNetwork(network)) {
        case Ok(:final value):
          registrations.addAll(value.wallets);
        case Err(:final failure):
          return Err(SwapStorageFailure(failure.logMessage));
      }
    }
    registrations.sort((a, b) => a.id.compareTo(b.id));
    final wallets = await Future.wait(
      registrations.map((registration) async {
        final device = await signerDevices().read(registration.id);
        return switch (device) {
          Ok(:final value) => Ok<SwapWallet, SwapFailure>(
            SwapWallet(
              registration,
              await _balance(registration),
              value != null,
            ),
          ),
          Err(:final failure) => Err<SwapWallet, SwapFailure>(
            SwapStorageFailure(failure.logMessage),
          ),
        };
      }),
    );
    final values = <SwapWallet>[];
    for (final wallet in wallets) {
      switch (wallet) {
        case Ok(:final value):
          values.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(values);
  }

  Future<BigInt?> _balance(WalletRegistration registration) async =>
      switch (await sync.loadWallet(
        WalletKey(id: registration.id, network: registration.network),
      )) {
        Ok(:final value) => value.balances.now.data?.totalSat,
        Err() => null,
      };
}
