import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

/// Reads the value paid to an address from the selected account's transaction.
class ReadSendRecipientAmountUsecase {
  final WalletInventory _inventory;
  final WalletNativeRuntime _runtime;

  const ReadSendRecipientAmountUsecase(this._inventory, this._runtime);

  Future<int> execute({
    required String psbtOrPset,
    required String address,
    required String walletId,
  }) async {
    final registration = switch (await _inventory.readWallet(walletId)) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception(failure.runtimeType),
    };
    final network = registration.network;
    if (network is BitcoinNetwork) {
      return switch (await bitcoinRecipientAmounts(
        psbt: psbtOrPset,
        network: network,
        recipients: [(address: address, amountSat: null)],
      )) {
        Ok(:final value) => value.single,
        Err(:final failure) => throw Exception(failure.runtimeType),
      };
    }
    final key = WalletKey(id: registration.id, network: network);
    final wallet = switch (await _runtime.wallet(key)) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception(failure.runtimeType),
    };
    return switch (await wallet.tx.liquidAmountToAddress(psbtOrPset, address)) {
      Ok(:final value) => value.toInt(),
      Err(:final failure) => throw Exception(failure.runtimeType),
    };
  }
}
