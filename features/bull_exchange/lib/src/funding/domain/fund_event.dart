import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

@immutable
sealed class FundFlowEvent {
  const FundFlowEvent();
}

final class FundAccountLoaded extends FundFlowEvent {
  final int attempt;
  final Result<FundingAccount, ExchangeReadFailure> read;

  const FundAccountLoaded(this.attempt, this.read);
}

final class FundRetryPressed extends FundFlowEvent {
  const FundRetryPressed();
}

final class FundJurisdictionPicked extends FundFlowEvent {
  final Jurisdiction jurisdiction;

  const FundJurisdictionPicked(this.jurisdiction);
}

final class FundRailPicked extends FundFlowEvent {
  final FundingRail rail;

  const FundRailPicked(this.rail);
}

final class FundConsentAccepted extends FundFlowEvent {
  const FundConsentAccepted();
}

final class FundConsentSubmitted extends FundFlowEvent {
  final int attempt;
  final Result<void, ExchangeWriteFailure> write;

  const FundConsentSubmitted(this.attempt, this.write);
}

final class FundConsentVerified extends FundFlowEvent {
  final int attempt;
  final Result<bool, ExchangeReadFailure> read;

  const FundConsentVerified(this.attempt, this.read);
}

final class FundInstitutionsLoaded extends FundFlowEvent {
  final int attempt;
  final Result<List<FundingInstitution>, ExchangeReadFailure> read;

  const FundInstitutionsLoaded(this.attempt, this.read);
}

final class FundCopSubmitted extends FundFlowEvent {
  final FundingInstitution institution;
  final CopAmount amount;

  const FundCopSubmitted(this.institution, this.amount);
}

final class FundRegularSepaChosen extends FundFlowEvent {
  const FundRegularSepaChosen();
}

final class FundInstructionsLoaded extends FundFlowEvent {
  final int attempt;
  final FundingRequest request;
  final Result<FundingAnswer, ExchangeReadFailure> read;

  const FundInstructionsLoaded(this.attempt, this.request, this.read);
}

/// Back, a dismissed sheet or a popped page.
final class FundBackPressed extends FundFlowEvent {
  const FundBackPressed();
}

final class FundDonePressed extends FundFlowEvent {
  const FundDonePressed();
}

/// The exchange access changed; [session] is the signed-in session, or null.
final class FundSessionChanged extends FundFlowEvent {
  final ExchangeSession? session;

  const FundSessionChanged(this.session);
}
