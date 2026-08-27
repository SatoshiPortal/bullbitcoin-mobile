import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:flutter/widgets.dart';

extension BullnymFailureL10n on BullnymFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BullnymNetworkFailure() => context.loc.bullnymErrorConnectionFailed,
    BullnymServerFailure(retryable: true) =>
      context.loc.bullnymErrorServerUnavailable,
    BullnymServerFailure() => context.loc.bullnymErrorServerError,
    BullnymInvalidInputFailure() ||
    BullnymAuthenticationFailure() ||
    BullnymInvalidResponseFailure() ||
    BullnymUnexpectedFailure() => context.loc.bullnymErrorUnexpected,
  };
}
