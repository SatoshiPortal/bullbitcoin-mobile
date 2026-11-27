import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_field_checks.dart';
import 'package:flutter/widgets.dart';

/// Form validators for the SPEI fields, using the same checks the domain
/// applies to a new recipient.
extension SpeiFieldValidators on BuildContext {
  String? validateSpeiClabe(String? value) =>
      _speiMessage(value, speiClabeProblem);

  String? validateSpeiPhone(String? value) =>
      _speiMessage(value, speiPhoneProblem);

  String? validateSpeiDebitCard(String? value) =>
      _speiMessage(value, speiDebitCardProblem);

  String? _speiMessage(String? value, SpeiProblem? Function(String) check) {
    if (value == null || value.trim().isEmpty) {
      return loc.recipientsValidationFieldRequired;
    }
    return switch (check(value)) {
      null => null,
      SpeiProblem.clabeNotEighteenDigits => loc.recipientsValidationClabeLength,
      SpeiProblem.clabeWrongCheckDigit =>
        loc.recipientsValidationClabeCheckDigit,
      SpeiProblem.phoneNotTenDigits => loc.recipientsValidationSpeiPhone,
      SpeiProblem.debitCardNotSixteenDigits =>
        loc.recipientsValidationDebitCard,
    };
  }
}
