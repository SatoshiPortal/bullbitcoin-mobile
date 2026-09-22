import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:flutter/widgets.dart';

extension RecipientsFailureL10n on RecipientsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientActivationFailure() => context.loc.oopsSomethingWentWrong,
    RecipientRefreshFailure() => context.loc.oopsSomethingWentWrong,
    VirtualIbanFailure() => context.loc.oopsSomethingWentWrong,
  };
}
