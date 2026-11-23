import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

class VerifyTransferLockupUsecase {
  final WalletNativeRuntime _sync;

  const VerifyTransferLockupUsecase(this._sync);

  Future<Result<void, SwapsInvalidLockupFailure>> execute({
    required String psbtOrPset,
    required Swap swap,
    required WalletKey wallet,
  }) => verifySwapLockupResult(
    swap,
    amountTo: (address) async {
      final network = wallet.network;
      if (network is BitcoinNetwork) {
        return (await bitcoinRecipientAmounts(
          psbt: psbtOrPset,
          network: network,
          recipients: [(address: address, amountSat: null)],
        )).map((amounts) => amounts.single);
      }
      return switch (await _sync.wallet(wallet)) {
        Ok(:final value) => (await value.tx.liquidAmountToAddress(
          psbtOrPset,
          address,
        )).map((amount) => amount.toInt()),
        Err(:final failure) => Err(failure),
      };
    },
  );
}
