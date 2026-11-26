import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/fee_preview.dart';
import 'package:sync/sync.dart' show Coin, WalletKey;
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'spend_options.dart';
import 'spend_options_runner.dart';

/// The wallet side of a sell or pay payin. [coins] lists a wallet's coins
/// (null when it can't).
typedef PayinWalletServices = ({
  Spend spend,
  Fees fees,
  PayjoinPolicyAccess payjoinPolicy,
  PayjoinSender payjoinSender,
  PayjoinSessions payjoinSessions,
  Labels labels,
  Future<List<Coin>?> Function(String walletId) coins,
});

/// A wallet's coins read through the inventory: only a wallet this device
/// signs for, null when it can't be read.
Future<List<Coin>?> Function(String walletId) walletCoinsOf(
  WalletInventory inventory,
  WalletNativeRuntime native,
) => (walletId) async {
  switch (await inventory.readWallet(walletId)) {
    case Ok(
      value: WalletRegistration(
        :final id,
        :final network,
        signer: WalletSigner.local,
      ),
    ):
      switch (await native.wallet(WalletKey(id: id, network: network))) {
        case Ok(:final value):
          return switch (await value.unspent()) {
            Ok(:final value) => value.toList(),
            Err() => null,
          };
        case Err():
          return null;
      }
    case Ok() || Err():
      return null;
  }
};

/// The spend options' calls of [session] over the wallet [services]: the
/// fee estimates of the session's network, the coins and unsigned previews
/// of the payin to the quoted deposit.
SpendOptionsCalls spendOptionsCallsOf(
  ExchangeSession session,
  PayinWalletServices services,
) {
  final bitcoin = session.environment == ExchangeEnvironment.testnet
      ? BitcoinNetwork.testnet
      : BitcoinNetwork.mainnet;
  final previews = SpendFeePreview();
  List<BitcoinTransactionRecipient> recipients(SpendPreviewShape shape) => [
    BitcoinTransactionRecipient.fixed(
      address: shape.target.address,
      amountSat: Sats.fromInt(shape.target.amountSat),
    ),
  ];
  return (
    fees: () async => switch (await services.fees.estimate(bitcoin)) {
      Ok(:final value) => value,
      Err() => null,
    },
    coins: services.coins,
    presets: (shape, fees) async {
      switch (await services.spend.previewBitcoinFeePresets(
        walletId: shape.walletId,
        recipients: recipients(shape),
        presets: fees,
        replaceByFee: shape.replaceByFee,
        selectedInputs: shape.coins,
      )) {
        case Ok(:final value):
          return {
            for (final MapEntry(key: selection, value: preview)
                in value.entries)
              selection: previews.project(preview),
          };
        case Err():
          return const {};
      }
    },
    custom: (shape, fee) async {
      switch (await services.spend.previewBitcoinFee(
        walletId: shape.walletId,
        recipients: recipients(shape),
        networkFee: fee,
        replaceByFee: shape.replaceByFee,
        selectedInputs: shape.coins,
      )) {
        case Ok(:final value):
          return previews.project(value);
        case Err():
          return const BitcoinFeePreviewSlot();
      }
    },
  );
}

/// The wallet fee of a payin's chosen [fee].
NetworkFee networkFeeOf(PayinFee fee) => switch (fee) {
  PayinFeeRate(:final satPerKwu) => NetworkFee.relativeSatPerKwu(satPerKwu),
  PayinFeeAbsolute(:final sats) => NetworkFee.absolute(sats),
  PayinFeeNetworkMinimum() => NetworkFeeRelayPolicy.minRelay,
};

/// The payin fee of a wallet [fee].
PayinFee payinFeeOf(NetworkFee fee) => switch (fee) {
  RelativeFee(:final satPerKwu) => PayinFeeRate(satPerKwu),
  AbsoluteFee(:final sats) => PayinFeeAbsolute(sats),
};
