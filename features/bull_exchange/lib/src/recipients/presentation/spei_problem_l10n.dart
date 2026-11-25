import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// The message shown under a SPEI field for each [SpeiProblem].
extension SpeiProblemL10n on SpeiProblem {
  String toTranslated(BuildContext context) => switch (this) {
    SpeiProblem.clabeNotEighteenDigits =>
      context.loc.recipientsValidationClabeLength,
    SpeiProblem.clabeWrongCheckDigit =>
      context.loc.recipientsValidationClabeCheckDigit,
    SpeiProblem.phoneNotTenDigits => context.loc.recipientsValidationSpeiPhone,
    SpeiProblem.debitCardNotSixteenDigits =>
      context.loc.recipientsValidationDebitCard,
  };
}

/// A form validator: required, then the domain's [check] of the field.
String? Function(String?) speiFieldValidator(
  BuildContext context,
  SpeiProblem? Function(String value) check,
) =>
    (v) => (v == null || v.trim().isEmpty)
    ? context.loc.recipientsValidationFieldRequired
    : check(v)?.toTranslated(context);
