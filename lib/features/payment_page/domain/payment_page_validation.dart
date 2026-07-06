import 'dart:convert';

import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';

// Byte caps mirror the server exactly (src/donation_page.rs). The server
// measures `String::len()` (UTF-8 bytes), NOT characters, so validation here is
// byte-based too — a multibyte header can fail the client pre-filter at fewer
// than 80 visible characters.
const int paymentPageHeaderMaxBytes = 80; // MAX_HEADER_LEN
const int paymentPageDescriptionMaxBytes = 280; // MAX_DESCRIPTION_LEN
const int paymentPageWebsiteMaxBytes = 200; // MAX_SOCIAL_LINK_LEN
const int paymentPageSocialHandleMaxBytes = 50; // MAX_SOCIAL_HANDLE_LEN

// Handle regexes copied verbatim from the server (src/donation_page.rs
// TWITTER_HANDLE_REGEX / INSTAGRAM_HANDLE_REGEX).
final RegExp _twitterHandleRegExp = RegExp(r'^[A-Za-z0-9_]{1,50}$');
final RegExp _instagramHandleRegExp = RegExp(r'^[A-Za-z0-9._]{1,50}$');

/// UTF-8 byte length — the unit the server validates in.
int paymentPageByteLength(String value) => utf8.encode(value).length;

bool isValidPaymentPageHeader(String value) {
  final bytes = paymentPageByteLength(value);
  return bytes >= 1 && bytes <= paymentPageHeaderMaxBytes;
}

bool isValidPaymentPageDescription(String value) {
  final bytes = paymentPageByteLength(value);
  return bytes >= 1 && bytes <= paymentPageDescriptionMaxBytes;
}

bool isValidPaymentPageWebsite(String value) {
  if (value.isEmpty) return true; // optional
  if (paymentPageByteLength(value) > paymentPageWebsiteMaxBytes) return false;
  return value.startsWith('https://');
}

bool isValidPaymentPageTwitter(String value) {
  if (value.isEmpty) return true; // optional
  return _twitterHandleRegExp.hasMatch(value);
}

bool isValidPaymentPageInstagram(String value) {
  if (value.isEmpty) return true; // optional
  return _instagramHandleRegExp.hasMatch(value);
}

/// The fields the editor collects, in the order the form presents them; used to
/// point per-field validation at the failing input.
enum PaymentPageField {
  header,
  description,
  displayCurrency,
  website,
  twitter,
  instagram,
}

/// A validating value object for a Donation Page save. Local validation is a UX
/// pre-filter — the server remains the authority — but it mirrors the server
/// rules exactly so a locally-valid page is not needlessly round-tripped.
class SavePaymentPageCommand {
  final String header;
  final String description;
  final String displayCurrency;
  final String website;
  final String twitter;
  final String instagram;

  const SavePaymentPageCommand({
    required this.header,
    required this.description,
    required this.displayCurrency,
    this.website = '',
    this.twitter = '',
    this.instagram = '',
  });

  /// The first field that fails validation, or null when the command is valid.
  PaymentPageField? firstInvalidField() {
    if (!isValidPaymentPageHeader(header)) return PaymentPageField.header;
    if (!isValidPaymentPageDescription(description)) {
      return PaymentPageField.description;
    }
    if (displayCurrency.isEmpty) return PaymentPageField.displayCurrency;
    if (!isValidPaymentPageWebsite(website)) return PaymentPageField.website;
    if (!isValidPaymentPageTwitter(twitter)) return PaymentPageField.twitter;
    if (!isValidPaymentPageInstagram(instagram)) {
      return PaymentPageField.instagram;
    }
    return null;
  }

  bool get isValid => firstInvalidField() == null;

  /// Throws [PaymentPageException.invalidInput] when any field is invalid. The
  /// invalid field name is carried as the diagnostic `code`.
  void validate() {
    final invalid = firstInvalidField();
    if (invalid != null) {
      throw PaymentPageException.invalidInput(code: invalid.name);
    }
  }
}
