import 'dart:convert';

import 'package:bb_mobile/features/pos/domain/pos_error.dart';

// Byte cap mirrors the server exactly (src/donation_page.rs MAX_HEADER_LEN):
// the POS label rides the shared `header` slot. The server measures
// `String::len()` (UTF-8 bytes), NOT characters, so validation here is
// byte-based too - a multibyte label can fail the client pre-filter at fewer
// than 80 visible characters. POS has NO description/socials/website/image
// rules: those fields are sent empty on the wire (DELTA 2).
const int posLabelMaxBytes = 80; // MAX_HEADER_LEN

/// UTF-8 byte length - the unit the server validates in.
int posByteLength(String value) => utf8.encode(value).length;

bool isValidPosLabel(String value) {
  final bytes = posByteLength(value);
  return bytes >= 1 && bytes <= posLabelMaxBytes;
}

/// The fields the POS provisioning form collects, in the order it presents them;
/// used to point per-field validation at the failing input.
enum PosField { label, displayCurrency }

/// A validating value object for a POS provision/edit. Local validation is a UX
/// pre-filter - the server remains the authority - but it mirrors the server
/// rules exactly so a locally-valid terminal is not needlessly round-tripped.
class PosProvisionCommand {
  final String label;
  final String displayCurrency;

  const PosProvisionCommand({
    required this.label,
    required this.displayCurrency,
  });

  /// The first field that fails validation, or null when the command is valid.
  PosField? firstInvalidField() {
    if (!isValidPosLabel(label)) return PosField.label;
    if (displayCurrency.isEmpty) return PosField.displayCurrency;
    return null;
  }

  bool get isValid => firstInvalidField() == null;

  /// Throws [PosException.invalidInput] when any field is invalid. The invalid
  /// field name is carried as the diagnostic `code`.
  void validate() {
    final invalid = firstInvalidField();
    if (invalid != null) {
      throw PosException.invalidInput(code: invalid.name);
    }
  }
}
