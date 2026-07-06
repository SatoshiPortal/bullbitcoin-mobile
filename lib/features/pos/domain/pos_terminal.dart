import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';

/// Builds the keyless PWA till terminal URL client-side (DG-P5): deterministic
/// and injection-proof. The base is the known bullnym base (the same value the
/// shared client is configured with) and the nym comes from our own resolved
/// registration - NO server-echoed `public_url` is trusted into this string, so
/// a hostile/oversized server value can never become the terminal URL.
String buildPosTerminalUrl({required String baseUrl, required String nym}) {
  final normalizedBase = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$normalizedBase/$nym/pos';
}

/// The Point of Sale as the product surface sees it - a faithful, read-only
/// mirror of the server row minus the confidential descriptor (which the server
/// view never echoes) and the page-only content fields (POS has none). The
/// [terminalUrl] is constructed client-side, never taken from the server.
class PosTerminal {
  final String nym;
  final String label;
  final String displayCurrency;
  final bool enabled;
  final bool isArchived;
  final String terminalUrl;

  const PosTerminal({
    required this.nym,
    required this.label,
    required this.displayCurrency,
    required this.enabled,
    required this.isArchived,
    required this.terminalUrl,
  });

  bool get isActive => enabled && !isArchived;

  /// Map the shared-client view into the product entity. A row whose `kind` is
  /// not `pos` reaching this feature is a wrong-surface response (hostile/buggy
  /// server, or a payment_page row) and is refused rather than rendered (§8.10).
  /// [baseUrl] is the known bullnym base used to construct the terminal URL.
  factory PosTerminal.fromBullnym(
    BullnymDonationPage page, {
    required String baseUrl,
  }) {
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
      terminalUrl: buildPosTerminalUrl(baseUrl: baseUrl, nym: page.nym),
    );
  }
}
