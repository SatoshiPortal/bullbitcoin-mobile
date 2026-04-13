import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';

/// Represents the action that was interrupted by the scam warning consent.
/// After the user consents, this action is re-dispatched.
sealed class PendingConsentAction {
  const PendingConsentAction();
}

/// User tapped a funding method that requires fetching funding details.
class PendingFundingDetailsAction extends PendingConsentAction {
  final FundingMethod method;

  const PendingFundingDetailsAction(this.method);

  @override
  bool operator ==(Object other) =>
      other is PendingFundingDetailsAction && other.method == method;

  @override
  int get hashCode => method.hashCode;
}

/// User tapped the Colombia COP bank transfer method,
/// which requires listing institutions before the input screen.
class PendingCopInputAction extends PendingConsentAction {
  const PendingCopInputAction();

  @override
  bool operator ==(Object other) => other is PendingCopInputAction;

  @override
  int get hashCode => runtimeType.hashCode;
}
