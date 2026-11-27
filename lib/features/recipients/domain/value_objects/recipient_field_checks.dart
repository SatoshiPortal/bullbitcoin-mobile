/// Checks of single recipient fields, shared by the forms and the domain.
library;

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [email] has the shape of an address: one `@`, a dot in the
/// domain, no spaces. The server checks deliverability, not the app.
bool emailLooksValid(String email) => _email.hasMatch(email.trim());

/// Why a SPEI (Mexico) field can't be sent.
enum SpeiProblem {
  clabeNotEighteenDigits,
  clabeWrongCheckDigit,
  phoneNotTenDigits,
  debitCardNotSixteenDigits,
}

final _eighteenDigits = RegExp(r'^\d{18}$');
final _tenDigits = RegExp(r'^\d{10}$');
final _sixteenDigits = RegExp(r'^\d{16}$');

/// The problem of a CLABE, or null for a valid one: 18 digits whose last is
/// the check digit of the first 17 (weights 3, 7, 1 repeating; each product
/// taken mod 10; check = (10 - sum mod 10) mod 10).
SpeiProblem? speiClabeProblem(String clabe) {
  final digits = clabe.trim();
  if (!_eighteenDigits.hasMatch(digits)) {
    return SpeiProblem.clabeNotEighteenDigits;
  }
  const weights = [3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += (int.parse(digits[i]) * weights[i % 3]) % 10;
  }
  final check = (10 - sum % 10) % 10;
  return int.parse(digits[17]) == check
      ? null
      : SpeiProblem.clabeWrongCheckDigit;
}

/// The problem of a SPEI phone number, or null for its 10 digits.
SpeiProblem? speiPhoneProblem(String phone) =>
    _tenDigits.hasMatch(phone.trim()) ? null : SpeiProblem.phoneNotTenDigits;

/// The problem of a SPEI debit card number, or null for its 16 digits.
SpeiProblem? speiDebitCardProblem(String debitCard) =>
    _sixteenDigits.hasMatch(debitCard.trim())
    ? null
    : SpeiProblem.debitCardNotSixteenDigits;
