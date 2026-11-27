import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart'
    show ExchangeWalletCoinsUnavailableFailure;
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show Coin, WalletKey;
import 'package:sync/write.dart' show WalletNativeRuntime;

/// The wallet side of a sell or pay payin. [coins] lists a wallet's coins.
typedef PayinWalletServices = ({
  Spend spend,
  Fees fees,
  PayjoinPolicyAccess payjoinPolicy,
  PayjoinSender payjoinSender,
  PayjoinSessions payjoinSessions,
  Labels labels,
  Future<Result<List<Coin>, ExchangeWalletCoinsUnavailableFailure>> Function(
    String walletId,
  )
  coins,
});

/// A wallet's coins read through the inventory: only a wallet this device
/// signs for.
Future<Result<List<Coin>, ExchangeWalletCoinsUnavailableFailure>> Function(
  String walletId,
)
walletCoinsOf(WalletInventory inventory, WalletNativeRuntime native) =>
    (walletId) async {
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
                Ok(:final value) => Ok(value.toList()),
                Err() => const Err(
                  ExchangeWalletCoinsUnavailableFailure('coins unreadable'),
                ),
              };
            case Err():
              return const Err(
                ExchangeWalletCoinsUnavailableFailure('wallet not opened'),
              );
          }
        case Ok():
          return const Err(
            ExchangeWalletCoinsUnavailableFailure('not signed on this device'),
          );
        case Err():
          return const Err(ExchangeWalletCoinsUnavailableFailure('not listed'));
      }
    };

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
