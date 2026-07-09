import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [AppUnlockFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns raw
/// [Failure.logMessage].
extension AppUnlockFailureL10n on AppUnlockFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AppUnlockPinCheckFailure() => context.loc.appUnlockPinCheckError,
    AppUnlockPinVerifyFailure() => context.loc.appUnlockPinVerifyError,
    AppUnlockUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
