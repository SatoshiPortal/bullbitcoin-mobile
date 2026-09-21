import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:flutter/widgets.dart';

extension RecipientsFailureL10n on RecipientsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    RecipientsInvalidSecurityDetailsFailure() =>
      context.loc.oopsSomethingWentWrong,
    RecipientsInvalidFieldsFailure() => context.loc.oopsSomethingWentWrong,
  };
}
