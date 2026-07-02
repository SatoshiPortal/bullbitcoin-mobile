import 'package:bb_mobile/core/failures/failure.dart';

sealed class ReplaceByFeeFailure extends Failure {
  const ReplaceByFeeFailure([super.logMessage]);
}

final class ReplaceByFeeNoFeeRateSelectedFailure extends ReplaceByFeeFailure {
  const ReplaceByFeeNoFeeRateSelectedFailure();
}

final class ReplaceByFeeFeeRateTooLowFailure extends ReplaceByFeeFailure {
  const ReplaceByFeeFeeRateTooLowFailure();
}

final class ReplaceByFeeNetworkFeesFailure extends ReplaceByFeeFailure {
  const ReplaceByFeeNetworkFeesFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class ReplaceByFeeUnexpectedFailure extends ReplaceByFeeFailure {
  const ReplaceByFeeUnexpectedFailure([super.logMessage]);
}
