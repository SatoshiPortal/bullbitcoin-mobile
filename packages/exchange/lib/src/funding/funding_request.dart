import 'package:meta/meta.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/catalog/jurisdiction.dart';
import '../domain/entities/confidential_sepa_availability.dart';
import '../domain/entities/funding_institution.dart';
import '../steps/consent_gate.dart';
import 'funding_instructions.dart';
import 'funding_rail.dart';

/// What the fund flow knows about the account, read once when it opens.
/// Every gate of the flow decides from it, never from a missing one (FUND-3).
@immutable
final class FundingAccount {
  final int userNumber;
  final String firstName;
  final String lastName;

  /// The account currency, or null when the account has none.
  final ParsedCurrency? currency;
  final bool restricted;
  final bool consented;
  final ConfidentialSepaAvailability confidentialSepa;

  const FundingAccount({
    required this.userNumber,
    required this.firstName,
    required this.lastName,
    required this.currency,
    required this.restricted,
    required this.consented,
    required this.confidentialSepa,
  });

  /// The jurisdiction the fund screen opens on: the account currency's (USD
  /// is Costa Rica). Null when the account has no currency this build
  /// knows: the user picks, there is no Canada default (D3).
  Jurisdiction? get jurisdiction => switch (currency) {
    KnownCurrency(:final market) => market.jurisdiction,
    UnknownCurrency() || null => null,
  };

  /// The rails the fund screen offers in [jurisdiction]. Confidential SEPA
  /// only when the account can use it.
  List<FundingRail> railsIn(Jurisdiction jurisdiction) => [
    for (final rail in FundingRails.of(jurisdiction))
      if (rail is! ConfidentialSepaFundingRail ||
          confidentialSepa != ConfidentialSepaAvailability.unavailable)
        rail,
  ];

  @override
  bool operator ==(Object other) =>
      other is FundingAccount &&
      other.userNumber == userNumber &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.currency == currency &&
      other.restricted == restricted &&
      other.consented == consented &&
      other.confidentialSepa == confidentialSepa;

  @override
  int get hashCode => Object.hash(
    userNumber,
    firstName,
    lastName,
    currency,
    restricted,
    consented,
    confidentialSepa,
  );

  @override
  String toString() => 'FundingAccount(#$userNumber)';
}

/// A COP amount: whole pesos, more than zero.
@immutable
final class CopAmount {
  final int pesos;

  const CopAmount._(this.pesos);

  /// The amount typed in [text] (digits only), or null when it is not a
  /// positive whole number.
  static CopAmount? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(trimmed)) return null;
    final pesos = int.tryParse(trimmed);
    return pesos == null || pesos <= 0 ? null : CopAmount._(pesos);
  }

  @override
  bool operator ==(Object other) => other is CopAmount && other.pesos == pesos;

  @override
  int get hashCode => pesos.hashCode;

  @override
  String toString() => 'CopAmount($pesos)';
}

/// A request for a rail's instructions. Every one holds the [ConsentGiven]
/// only the consent gate makes, so no instructions can be fetched without
/// consent (FUND-4).
@immutable
sealed class FundingRequest {
  final ConsentGiven consent;

  const FundingRequest._(this.consent);

  FundingRail get rail;
}

final class ProcessorCodeRequest extends FundingRequest {
  @override
  final ProcessorCodeFundingRail rail;

  /// The e-Transfer secret answer; from the loaded account (03 §12.3).
  final int userNumber;

  const ProcessorCodeRequest(
    this.rail, {
    required this.userNumber,
    required ConsentGiven consent,
  }) : super._(consent);

  @override
  bool operator ==(Object other) =>
      other is ProcessorCodeRequest &&
      other.rail == rail &&
      other.userNumber == userNumber;

  @override
  int get hashCode => Object.hash(rail, userNumber);

  @override
  String toString() => 'ProcessorCodeRequest(${rail.name})';
}

final class CopPaymentRequest extends FundingRequest {
  final FundingInstitution institution;
  final CopAmount amount;

  const CopPaymentRequest({
    required this.institution,
    required this.amount,
    required ConsentGiven consent,
  }) : super._(consent);

  @override
  CopBankTransferFundingRail get rail => const CopBankTransferFundingRail();

  @override
  bool operator ==(Object other) =>
      other is CopPaymentRequest &&
      other.institution.code == institution.code &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(institution.code, amount);

  @override
  String toString() => 'CopPaymentRequest(${institution.code}, $amount)';
}

/// Why the exchange refused a rail's instructions. A refusal is an answer,
/// shown with its own copy; an unknown refusal code is an unreadable answer.
enum FundingRefusal {
  /// `ERR_ORD_PO404`
  paymentOptionUnavailable,

  /// `ERR_RCP_PO404`
  optionNotPermitted,

  /// `ERR_RCP_POSINPE404`: the user's SINPE number is not registered.
  sinpeNotRegistered,

  /// `ERR_ORD_KYC400`
  kycIncomplete,

  /// `ERR_ORD_COP400`
  copRequestInvalid,

  /// `ERR_ORD_CSRCP400`
  sepaVirtualPaymentInactive,

  /// `ERR_RCP_400`
  requestInvalid,
}

/// The exchange's answer to a [FundingRequest].
@immutable
sealed class FundingAnswer {
  const FundingAnswer();
}

final class FundingInstructionsGot extends FundingAnswer {
  final FundingInstructions instructions;

  const FundingInstructionsGot(this.instructions);

  @override
  bool operator ==(Object other) =>
      other is FundingInstructionsGot && other.instructions == instructions;

  @override
  int get hashCode => instructions.hashCode;
}

final class FundingRefused extends FundingAnswer {
  final FundingRefusal reason;

  const FundingRefused(this.reason);

  @override
  bool operator ==(Object other) =>
      other is FundingRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}
