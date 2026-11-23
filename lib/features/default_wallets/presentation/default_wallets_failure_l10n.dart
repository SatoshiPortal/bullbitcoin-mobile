import 'package:exchange/exchange.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/default_wallets/domain/default_wallets_failure.dart';
import 'package:flutter/widgets.dart';

extension DefaultWalletsFailureL10n on DefaultWalletsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    DefaultWalletsLoadFailure() => context.loc.exchangeBitcoinWalletsLoadFailed,
    DefaultWalletsEmptyAddressFailure() =>
      context.loc.exchangeBitcoinWalletsAddressEmpty,
    DefaultWalletsInvalidAddressFailure(:final type) =>
      context.loc.destinationExpectedType(switch (type) {
        WalletAddressType.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
        WalletAddressType.liquid => context.loc.exchangeDcaAddressLabelLiquid,
        WalletAddressType.lightning =>
          context.loc.exchangeDcaAddressLabelLightning,
      }),
    DefaultWalletsSaveFailure() => context.loc.exchangeBitcoinWalletsSaveFailed,
    DefaultWalletsDeleteFailure() =>
      context.loc.exchangeBitcoinWalletsDeleteFailed,
  };
}
