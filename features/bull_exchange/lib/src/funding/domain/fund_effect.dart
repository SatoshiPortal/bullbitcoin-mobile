import 'package:exchange/funding.dart';
import 'package:meta/meta.dart';

@immutable
sealed class FundFlowEffect {
  const FundFlowEffect();
}

final class FundLoadAccount extends FundFlowEffect {
  final int attempt;

  const FundLoadAccount(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundLoadAccount && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundLoadAccount, attempt);
}

final class FundSubmitConsent extends FundFlowEffect {
  final int attempt;

  const FundSubmitConsent(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundSubmitConsent && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundSubmitConsent, attempt);
}

final class FundVerifyConsent extends FundFlowEffect {
  final int attempt;

  const FundVerifyConsent(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundVerifyConsent && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundVerifyConsent, attempt);
}

final class FundLoadInstitutions extends FundFlowEffect {
  final int attempt;

  const FundLoadInstitutions(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FundLoadInstitutions && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FundLoadInstitutions, attempt);
}

final class FundFetchInstructions extends FundFlowEffect {
  final int attempt;
  final FundingRequest request;

  const FundFetchInstructions(this.attempt, this.request);

  @override
  bool operator ==(Object other) =>
      other is FundFetchInstructions &&
      other.attempt == attempt &&
      other.request == request;

  @override
  int get hashCode => Object.hash(FundFetchInstructions, attempt, request);
}
