import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

/// The amount field's text and the amount step's draft text are the same
/// except for a bitcoin amount shown in sats: the draft holds BTC.
abstract final class BuyAmountText {
  static const _satsPerBitcoin = 100000000;

  /// The draft text for what the field shows.
  static String toDraft(String field, AmountUnit unit, BitcoinUnit display) {
    final text = field.replaceAll(',', '.').replaceAll(' ', '').trim();
    if (unit == AmountUnit.fiat || display == BitcoinUnit.btc) return text;
    final sats = int.tryParse(text);
    if (sats == null) return text;
    final btc = (sats / _satsPerBitcoin).toStringAsFixed(8);
    return btc.contains('.')
        ? btc.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : btc;
  }

  /// What the field shows for the draft text.
  static String toField(String draft, AmountUnit unit, BitcoinUnit display) {
    if (unit == AmountUnit.fiat || display == BitcoinUnit.btc) return draft;
    final btc = double.tryParse(draft);
    return btc == null ? draft : (btc * _satsPerBitcoin).round().toString();
  }
}
