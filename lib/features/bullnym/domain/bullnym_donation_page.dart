const bullnymDonationPageKindPaymentPage = 'payment_page';
const bullnymDonationPageKindPos = 'pos';

final class BullnymDonationPage {
  final String nym;
  final String header;
  final String description;
  final String displayCurrency;
  final String? website;
  final String? twitter;
  final String? instagram;
  final String kind;
  final bool enabled;
  final bool isArchived;
  final String? avatarSha256;
  final String? ogSha256;
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
    required this.enabled,
    required this.isArchived,
    this.avatarSha256,
    this.ogSha256,
    this.alias,
    required this.publicUrl,
  });

  bool get posMode => kind == bullnymDonationPageKindPos;
}

final class BullnymSupportedCurrency {
  final String code;
  final int precision;

  const BullnymSupportedCurrency({required this.code, required this.precision});
}

final class BullnymSupportedCurrencies {
  final List<BullnymSupportedCurrency> currencies;

  const BullnymSupportedCurrencies(this.currencies);
}
