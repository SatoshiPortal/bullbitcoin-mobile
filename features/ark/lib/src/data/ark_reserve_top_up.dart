import 'package:ark/ark.dart';
import 'package:fees/fees.dart' show Fees, NetworkFee;
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import '../domain/ark_failure.dart';
import '../domain/ark_reserve_top_up_port.dart';

/// Tops the Ark fee reserve up from the Secure Bitcoin wallet the Ark account
/// belongs to, through the app's own send for that wallet.
final class WalletArkReserveTopUp implements ArkReserveTopUpPort {
  final Future<Result<String, ArkFailure>> Function(ArkAccountId account)
  _sourceWallet;

  /// Sends [amount] to [address] from [walletId]; its txid, or a failure.
  final Future<Result<String, ArkFailure>> Function(
    String walletId,
    String address,
    Sats amount,
  )
  _send;

  const WalletArkReserveTopUp({
    required this._sourceWallet,
    required this._send,
  });

  @override
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  }) async {
    switch (await _sourceWallet(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final walletId):
        return _send(walletId, address, amount);
    }
  }
}

/// Builds its top-up on first use, so opening Ark never needs the wallet's
/// send stack: only an exit that must top the reserve up does.
final class DeferredArkReserveTopUp implements ArkReserveTopUpPort {
  final ArkReserveTopUpPort Function() _build;
  ArkReserveTopUpPort? _built;

  DeferredArkReserveTopUp(this._build);

  @override
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  }) => (_built ??= _build()).topUp(account, address: address, amount: amount);
}

/// The wallet's ordinary send, for Ark's fee reserve top-ups: brought up to
/// date by [synchronize] first so bitcoin added while an exit waited can
/// be spent, then built by [spend] at [fees]' fastest rate for
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
