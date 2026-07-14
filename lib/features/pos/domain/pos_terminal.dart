import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';

/// The Point of Sale as the product surface sees it - a faithful, read-only
/// mirror of the server row minus the confidential descriptor (which the server
/// view never echoes) and the page-only content fields (POS has none). The
/// [terminalUrl] is the canonical URL validated by the shared Bullnym client
/// against the trusted public origin and the returned nym/alias route.
class PosTerminal {
  final String nym;
  final String label;
  final String displayCurrency;
  final bool enabled;
  final bool isArchived;
  final String? alias;
  final String terminalUrl;

  const PosTerminal({
    required this.nym,
    required this.label,
    required this.displayCurrency,
    required this.enabled,
    required this.isArchived,
    this.alias,
    required this.terminalUrl,
  });

  bool get isActive => enabled && !isArchived;

  /// Map the shared-client view into the product entity. A row whose `kind` is
  /// not `pos` reaching this feature is a wrong-surface response (hostile/buggy
  /// server, or a payment_page row) and is refused rather than rendered (§8.10).
  factory PosTerminal.fromBullnym(BullnymDonationPage page) {
    if (page.kind != bullnymDonationPageKindPos) {
      throw const PosException.invalidServerResponse();
    }
    return PosTerminal(
      nym: page.nym,
      // The POS label is carried in the shared `header` slot on the wire.
      label: page.header,
      displayCurrency: page.displayCurrency,
      enabled: page.enabled,
      isArchived: page.isArchived,
      alias: page.alias,
      terminalUrl: page.publicUrl,
    );
  }
}
