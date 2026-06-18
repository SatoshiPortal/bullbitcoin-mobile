import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [LabelFailure]. The `sealed` switch
/// makes a missing message a compile error. Never returns the raw `logMessage`.
extension LabelFailureL10n on LabelFailure {
  String toTranslated(BuildContext context) => switch (this) {
        LabelNotFoundFailure(:final label) =>
          context.loc.labelErrorNotFound(label),
        UnsupportedLabelTypeFailure() =>
          context.loc.labelErrorUnsupportedType,
        SystemLabelCannotBeDeletedFailure() =>
          context.loc.labelErrorSystemCannotDelete,
        LabelUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
