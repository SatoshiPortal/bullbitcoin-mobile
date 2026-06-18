import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [PinCodeFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw `logMessage`.
extension PinCodeFailureL10n on PinCodeFailure {
  String toTranslated(BuildContext context) => switch (this) {
        PinCodeSaveFailure() => context.loc.pinCodeSaveError,
        PinCodeDeleteFailure() => context.loc.pinCodeDeleteError,
        PinCodeNotSetFailure() => context.loc.pinCodeNotSetError,
        PinCodeUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
