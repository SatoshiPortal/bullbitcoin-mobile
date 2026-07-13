import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:flutter/widgets.dart';

extension BullnymFailureL10n on BullnymFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BullnymNetworkFailure() ||
    BullnymTimeoutFailure() => context.loc.bullnymErrorConnectionFailed,
    BullnymServerRejectedRequestFailure(retryable: true) =>
      context.loc.bullnymErrorServerUnavailable,
    BullnymServerRejectedRequestFailure() =>
      context.loc.bullnymErrorServerError,
    BullnymInvalidInputFailure() ||
    BullnymUnexpectedHttpStatusFailure() ||
    BullnymEmptyResponseFailure() ||
    BullnymInvalidServerResponseFailure() ||
    BullnymSigningFailedFailure() ||
    BullnymUnexpectedFailure() => context.loc.bullnymErrorUnexpected,
  };
}
