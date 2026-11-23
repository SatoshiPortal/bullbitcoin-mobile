import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_failure.dart';
import 'package:flutter/widgets.dart';

extension DefaultWalletsFailureL10n on DefaultWalletsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    DefaultWalletsLoadFailure() => context.loc.exchangeBitcoinWalletsLoadFailed,
    DefaultWalletsEmptyAddressFailure() =>
      context.loc.exchangeBitcoinWalletsAddressEmpty,
    DefaultWalletsInvalidAddressFailure(:final type) =>
      context.loc.destinationExpectedType(switch (type) {
        BtcNetwork.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
        BtcNetwork.liquid => context.loc.exchangeDcaAddressLabelLiquid,
        BtcNetwork.lightning => context.loc.exchangeDcaAddressLabelLightning,
      }),
    DefaultWalletsSaveFailure() => context.loc.exchangeBitcoinWalletsSaveFailed,
    DefaultWalletsDeleteFailure() =>
      context.loc.exchangeBitcoinWalletsDeleteFailed,
  };
}
