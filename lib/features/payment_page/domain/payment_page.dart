import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';

/// The Donation Page as the product surface sees it — a faithful, read-only
/// mirror of the server row minus the confidential descriptor (which the server
/// view never echoes) and the image hashes (this fork does not manage images).
class PaymentPage {
  final String nym;
  final String header;
  final String description;
  final String displayCurrency;
  final String? website;
  final String? twitter;
  final String? instagram;
  final bool enabled;
  final bool isArchived;
  final String publicUrl;

  const PaymentPage({
    required this.nym,
    required this.header,
    required this.description,
    required this.displayCurrency,
    this.website,
    this.twitter,
    this.instagram,
    required this.enabled,
    required this.isArchived,
    required this.publicUrl,
  });

  bool get isActive => enabled && !isArchived;

  /// Map the shared-client view into the product entity. A row whose `kind` is
  /// not `payment_page` reaching this feature is a wrong-surface response
  /// (hostile/buggy server, or a POS row) and is refused rather than rendered
  /// (§8.10).
  factory PaymentPage.fromBullnym(BullnymDonationPage page) {
    if (page.kind != bullnymDonationPageKindPaymentPage) {
      throw const PaymentPageException.invalidServerResponse();
    }
    return PaymentPage(
      nym: page.nym,
      header: page.header,
      description: page.description,
      displayCurrency: page.displayCurrency,
      website: page.website,
      twitter: page.twitter,
      instagram: page.instagram,
      enabled: page.enabled,
      isArchived: page.isArchived,
      publicUrl: page.publicUrl,
    );
  }
}
