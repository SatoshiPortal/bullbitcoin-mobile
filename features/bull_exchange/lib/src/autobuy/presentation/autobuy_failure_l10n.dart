import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:flutter/widgets.dart';

extension AutoBuyFailureL10n on AutoBuyFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AutoBuyUnsupportedNetworkFailure() => context.loc.networkFeatureUnavailable,
    AutoBuyAccountUnavailableFailure() =>
      context.loc.autoBuyAccountUnavailableError,
    AutoBuyFundingRestrictedFailure() =>
      context.loc.fundExchangeRestrictedMessage,
    AutoBuyWalletRequiredFailure() => context.loc.autoBuyWalletRequiredError,
    AutoBuyPreferenceUpdateFailure() ||
    AutoBuyStatusUnconfirmedFailure() => context.loc.autoBuyUpdateError,
    AutoBuyUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
