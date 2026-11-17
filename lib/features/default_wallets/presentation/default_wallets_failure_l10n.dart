import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/default_wallets/domain/default_wallets_failure.dart';
import 'package:flutter/widgets.dart';

extension DefaultWalletsFailureL10n on DefaultWalletsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    DefaultWalletsLoadFailure() => context.loc.exchangeBitcoinWalletsLoadFailed,
    DefaultWalletsEmptyAddressFailure() =>
      context.loc.exchangeBitcoinWalletsAddressEmpty,
    DefaultWalletsSaveFailure() => context.loc.exchangeBitcoinWalletsSaveFailed,
    DefaultWalletsDeleteFailure() =>
      context.loc.exchangeBitcoinWalletsDeleteFailed,
  };
}
