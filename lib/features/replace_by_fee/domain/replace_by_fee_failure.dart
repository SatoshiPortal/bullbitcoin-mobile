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

/// The original transaction's wallet-owned input signatures failed
/// verification: it cannot have been produced by this wallet's keys and was
/// most likely planted by the Electrum server to bait a fee bump that pays
/// an attacker (GHSA-6jp4-8v48-cc5v). The bump is refused.
final class ReplaceByFeeManipulatedTransactionFailure
    extends ReplaceByFeeFailure {
  const ReplaceByFeeManipulatedTransactionFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class ReplaceByFeeUnexpectedFailure extends ReplaceByFeeFailure {
  const ReplaceByFeeUnexpectedFailure([super.logMessage]);
}
