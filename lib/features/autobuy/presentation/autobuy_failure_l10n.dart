import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:flutter/widgets.dart';

extension AutoBuyFailureL10n on AutoBuyFailure {
  String toTranslated(BuildContext context) => switch (this) {
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
