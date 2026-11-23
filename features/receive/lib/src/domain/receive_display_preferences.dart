import 'package:primitives/primitives.dart';

/// The amount display choices needed by the receive flow.
final class ReceiveDisplayPreferences {
  final BitcoinUnit bitcoinUnit;
  final String currencyCode;

  const ReceiveDisplayPreferences({
    required this.bitcoinUnit,
    required this.currencyCode,
  });
}
