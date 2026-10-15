import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// How numbers are written in the app.
///
/// French writes `7 123,51`: a no-break space between thousands and a comma
/// before the decimals. Every other language writes `7,123.51`. That split is
/// the agreed product rule (#2980), not an oversight: don't switch other
/// languages to their own CLDR separators without changing that decision.
///
/// The app picks the language once at its root with [useLanguage], so callers
/// without a `BuildContext` (bloc states, failure messages) follow the same
/// rule as the screens.
abstract final class BullNumberFormat {
  /// U+00A0 rather than the U+202F narrow space French data uses: every font
  /// has a glyph for it, and it still keeps `7 123` on one line.
  static const _frenchGroupSeparator = '\u00A0';

  static final _language = ValueNotifier<String>('en');

  static bool get _french => _language.value == 'fr';

  /// Notifies when [useLanguage] changes the language, so text written with
  /// the previous separators can be rewritten.
  static Listenable get languageChanges => _language;

  /// Switches the separators to the given app language code, e.g. `fr`.
  static void useLanguage(String languageCode) {
    _language.value = languageCode;
  }

  /// The separator before the decimals: `,` in French, `.` otherwise.
  static String get decimalSeparator => _french ? ',' : '.';

  /// The separator between thousands: a no-break space in French, `,`
  /// otherwise.
  static String get groupSeparator => _french ? _frenchGroupSeparator : ',';

  /// Turns a raw amount as the app stores it while typing (`1234.5`, `0.`)
  /// into what an input field shows (`1,234.5`, `0.` / `1 234,5`, `0,`).
  ///
  /// Unlike [decimal] it keeps the text exactly as typed: trailing zeros and a
  /// trailing separator stay, nothing is rounded.
  static String toInputText(String raw) {
    if (raw.isEmpty) return raw;
    final dot = raw.indexOf('.');
    final whole = dot == -1 ? raw : raw.substring(0, dot);
    if (!RegExp(r'^\d*$').hasMatch(whole)) return raw;

    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(groupSeparator);
      grouped.write(whole[i]);
    }
    if (dot == -1) return grouped.toString();
    return '$grouped$decimalSeparator${raw.substring(dot + 1)}';
  }

  /// Reverses [toInputText]: `1 234,5` or `1,234.5` back to `1234.5`.
  static String fromInputText(String text) {
    final ungrouped = text.replaceAll(groupSeparator, '');
    return _french ? ungrouped.replaceAll(',', '.') : ungrouped;
  }

  /// Formats [value] with between [minDecimals] and [maxDecimals] decimals,
  /// grouping thousands unless [grouping] is false.
  static String decimal(
    num value, {
    int minDecimals = 0,
    int maxDecimals = 2,
    bool grouping = true,
  }) {
    assert(minDecimals >= 0 && minDecimals <= maxDecimals);
    final integerPattern = grouping ? '#,##0' : '0';
    final decimalPattern = maxDecimals == 0
        ? ''
        : '.${'0' * minDecimals}${'#' * (maxDecimals - minDecimals)}';
    final formatted = NumberFormat(
      '$integerPattern$decimalPattern',
      'en_US',
    ).format(value);
    if (!_french) return formatted;

    return formatted.replaceAllMapped(
      RegExp('[,.]'),
      (match) => match[0] == ',' ? _frenchGroupSeparator : ',',
    );
  }
}
