import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';

// Data-layer constant: the donation-page surface discriminator for the Payment
// Page. The payment_page feature pins this; the shared client keeps `kind`
// generic so the future POS surface reuses the same wire methods with `pos`.
const String bullnymDonationPageKindPaymentPage = 'payment_page';

// Data-layer constant: the donation-page surface discriminator for the Point of
// Sale. The pos feature pins this on every save/archive/GET so POS sales settle
// to wallet 103; it rides the SAME wire methods as the page (only `kind`
// differs). `pos_mode` is never sent - POS is a kind, never a mode.
const String bullnymDonationPageKindPos = 'pos';

/// Mirror of the server `DonationPageView` (public read of the current row).
///
/// The view NEVER echoes `ct_descriptor`, so this DTO does not carry it. JSON
/// keys mirror the server exactly: `display_currency`, `is_archived`,
/// `avatar_sha256`, `og_sha256`, `public_url`. `posMode` is not a wire field:
/// the server dropped `pos_mode` and the client derives it from `kind`.
class BullnymDonationPage {
  final String nym;
  final String header;
  final String description;
  final String displayCurrency;
  final String? website;
  final String? twitter;
  final String? instagram;
  final String kind;
  final bool posMode;
  final bool enabled;
  final bool isArchived;
  final String? avatarSha256;
  final String? ogSha256;

  /// Permanent owner-level alias shared by Payment Page and POS. It remains
  /// owned independently of either surface's availability.
  final String? alias;
  final String publicUrl;

  const BullnymDonationPage({
    required this.nym,
    required this.header,
    required this.description,
    required this.displayCurrency,
    this.website,
    this.twitter,
    this.instagram,
    required this.kind,
    required this.posMode,
    required this.enabled,
    required this.isArchived,
    this.avatarSha256,
    this.ogSha256,
    this.alias,
    required this.publicUrl,
  });
}

/// A signed `PUT /donation-page` upsert. Optional social fields serialize as
/// empty strings (never omitted) so the signed byte layout is stable. `kind` is
/// always present; a first alias claim is the newest terminal signed field.
/// Preserve omits the alias JSON key and signed field entirely. `pos_mode` is
/// never sent (never in the JSON body, never signed).
class BullnymSaveDonationPageRequest {
  final String nym;
  final String ctDescriptor;
  final String header;
  final String description;
  final String displayCurrency;
  final String website;
  final String twitter;
  final String instagram;
  final bool enabled;
  final String kind;
  final BullnymAliasIntent aliasIntent;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymSaveDonationPageRequest({
    required this.nym,
    required this.ctDescriptor,
    required this.header,
    required this.description,
    required this.displayCurrency,
    required this.website,
    required this.twitter,
    required this.instagram,
    required this.enabled,
    required this.kind,
    this.aliasIntent = const BullnymAliasIntent.preserve(),
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

/// A signed `DELETE /donation-page` soft-archive. `kind` is the sole
/// optional-trailing signed field for archive and is always present here.
class BullnymArchiveDonationPageRequest {
  final String nym;
  final String kind;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymArchiveDonationPageRequest({
    required this.nym,
    required this.kind,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

/// One entry of the server `/api/v1/supported-currencies` list.
class BullnymSupportedCurrency {
  final String code;
  final int precision;

  const BullnymSupportedCurrency({required this.code, required this.precision});
}

/// The `/api/v1/supported-currencies` response (`{currencies: [...]}`).
class BullnymSupportedCurrencies {
  final List<BullnymSupportedCurrency> currencies;

  const BullnymSupportedCurrencies({required this.currencies});
}
