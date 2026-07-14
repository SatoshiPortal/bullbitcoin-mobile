import 'dart:convert';

import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:characters/characters.dart';

// Caps mirror the server exactly (src/donation_page.rs / src/og_image.rs).
// Header and link limits remain UTF-8 byte based.
// The social-preview description has a merchant-facing grapheme limit plus a defensive byte cap.
const int paymentPageHeaderMaxBytes = 80; // MAX_HEADER_LEN
const int paymentPageDescriptionMaxCharacters = 120;
const int paymentPageDescriptionMaxBytes = 512;
const int paymentPageWebsiteMaxBytes = 200; // MAX_SOCIAL_LINK_LEN
const int paymentPageSocialHandleMaxBytes = 50; // MAX_SOCIAL_HANDLE_LEN

// Handle regexes copied verbatim from the server (src/donation_page.rs
// TWITTER_HANDLE_REGEX / INSTAGRAM_HANDLE_REGEX).
final RegExp _twitterHandleRegExp = RegExp(r'^[A-Za-z0-9_]{1,50}$');
final RegExp _instagramHandleRegExp = RegExp(r'^[A-Za-z0-9._]{1,50}$');

/// UTF-8 byte length — the unit the server validates in.
int paymentPageByteLength(String value) => utf8.encode(value).length;

/// User-perceived Unicode characters (extended grapheme clusters), matching the server's Payment Page social-preview validation.
int paymentPageCharacterLength(String value) => value.characters.length;

bool isValidPaymentPageHeader(String value) {
  final bytes = paymentPageByteLength(value);
  return value.trim().isNotEmpty && bytes <= paymentPageHeaderMaxBytes;
}

bool isValidPaymentPageDescription(String value) {
  return value.trim().isNotEmpty &&
      paymentPageCharacterLength(value) <=
          paymentPageDescriptionMaxCharacters &&
      paymentPageByteLength(value) <= paymentPageDescriptionMaxBytes;
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

/// Submit-time normalization for the Donation Page website: a non-empty value
/// with no URL scheme gets an `https://` prefix (so `aa.com` becomes
/// `https://aa.com`); an existing `http://`/`https://` (any case) is left
/// untouched. Empty stays empty. Surrounding whitespace is trimmed.
String normalizePaymentPageUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('https://') || lower.startsWith('http://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

/// Submit-time normalization for a social handle: strips a single leading `@`
/// (users type `@name`) and trims surrounding whitespace. Empty stays empty.
String stripHandleAt(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('@')) return trimmed.substring(1);
  return trimmed;
}

String normalizePaymentPageAlias(String value) => value.trim().toLowerCase();

bool isValidPaymentPageAliasClaim(String? value) {
  if (value == null) return true;
  try {
    BullnymPublicName.aliasClaim(normalizePaymentPageAlias(value));
    return true;
  } on ArgumentError {
    return false;
  }
}

/// The fields the editor collects, in the order the form presents them; used to
/// point per-field validation at the failing input.
enum PaymentPageField {
  alias,
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
  final String? aliasClaim;

  const SavePaymentPageCommand({
    required this.header,
    required this.description,
    required this.displayCurrency,
    this.website = '',
    this.twitter = '',
    this.instagram = '',
    this.aliasClaim,
  });

  /// The first field that fails validation, or null when the command is valid.
  PaymentPageField? firstInvalidField() {
    if (!isValidPaymentPageAliasClaim(aliasClaim)) {
      return PaymentPageField.alias;
    }
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

  String? get normalizedAliasClaim =>
      aliasClaim == null ? null : normalizePaymentPageAlias(aliasClaim!);

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
