import 'package:bb_mobile/core/failures/failure.dart';

sealed class AutoBuyFailure extends Failure {
  const AutoBuyFailure([super.logMessage]);
}

final class AutoBuyAccountUnavailableFailure extends AutoBuyFailure {
  const AutoBuyAccountUnavailableFailure([super.logMessage]);
}

final class AutoBuyFundingRestrictedFailure extends AutoBuyFailure {
  const AutoBuyFundingRestrictedFailure([super.logMessage]);
}

final class AutoBuyWalletRequiredFailure extends AutoBuyFailure {
  const AutoBuyWalletRequiredFailure([super.logMessage]);
}

final class AutoBuyPreferenceUpdateFailure extends AutoBuyFailure {
  const AutoBuyPreferenceUpdateFailure([super.logMessage]);
}

final class AutoBuyStatusUnconfirmedFailure extends AutoBuyFailure {
  const AutoBuyStatusUnconfirmedFailure([super.logMessage]);
}

final class AutoBuyUnexpectedFailure extends AutoBuyFailure {
  const AutoBuyUnexpectedFailure([super.logMessage]);
}
