import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:flutter/widgets.dart';

extension DcaFailureL10n on DcaFailure {
  String toTranslated(BuildContext context) => switch (this) {
    DcaAccountUnavailableFailure() => context.loc.dcaAccountUnavailableError,
    DcaLightningAddressRequiredFailure() =>
      context.loc.dcaLightningAddressRequiredError,
    DcaReceiveAddressFailure() => context.loc.dcaReceiveAddressError,
    DcaOrderCreationFailure() => context.loc.dcaOrderCreationError,
    DcaUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
