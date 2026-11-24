import 'package:bull_ark/ark_setup.dart';
import 'package:fees/fees.dart' show Fees, NetworkFee;
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

/// The wallet's ordinary send, for Ark's fee reserve top-ups: brought up to
/// date by [synchronize] first (bitcoin added while an exit waited counts
/// without a refresh), built by [spend] at [fees]' fastest rate for
/// [network], signed under the wallet's own guards and broadcast through
/// its writer.
Future<Result<String, ArkFailure>> Function(
  String walletId,
  String address,
  Sats amount,
)
arkReserveSend({
  required BitcoinNetwork network,
  required Spend spend,
  required Fees fees,
  required Future<void> Function(String walletId) synchronize,
}) => (walletId, address, amount) async {
  try {
    await synchronize(walletId);
  } on Exception {
    // An older view of the wallet can only make the send refuse.
  }
  final NetworkFee fastest;
  switch (await fees.estimate(network)) {
    case Ok(:final value):
      fastest = value.fastest;
    case Err():
      return const Err(ArkNetworkUnavailableFailure());
  }
  final PreparedBitcoinSpend prepared;
  switch (await spend.prepareBitcoin(
    walletId: walletId,
    recipients: [
      BitcoinTransactionRecipient.fixed(address: address, amountSat: amount),
    ],
    networkFee: fastest,
  )) {
    case Ok(:final value):
      prepared = value;
    case Err(
      failure: SpendInsufficientFundsFailure() ||
          SpendInsufficientFundsForFeesFailure() ||
          SpendNoSpendableInputsFailure(),
    ):
      return const Err(ArkPaymentInsufficientFundsFailure());
    case Err():
      return const Err(ArkServiceUnavailableFailure());
  }
  final SignedBitcoinSpend signed;
  switch (await spend.signBitcoin(prepared: prepared)) {
    case Ok(:final value):
      signed = value;
    case Err():
      // Refused before anything left the wallet.
      return const Err(ArkServiceUnavailableFailure());
  }
  return switch (await spend.broadcastBitcoin(signed)) {
    Ok(:final value) => Ok(value.txid),
    // Signed, and the broadcast may have reached the network.
    Err() => const Err(ArkSubmissionUncertainFailure('reserve-top-up')),
  };
};
