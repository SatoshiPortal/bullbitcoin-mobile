import 'dart:io';

import 'package:bull_ui/src/data_display/bull_value_viewer.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Width of any truncation under [measureChars]: one unit per character.
const double _charWidth = 10;

/// The bech32 data alphabet a Lightning invoice is drawn from.
const String _bech32 = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

/// The lowercase hexadecimal alphabet a transaction id is drawn from.
const String _hex = '0123456789abcdef';

double measureChars(String text, TextStyle style) => text.length * _charWidth;

/// A Lightning invoice is a single unbreakable token; this is its length class
/// (383 characters for the regtest invoice measured on the Galaxy S10e).
String invoiceOf(int length) => 'lnbcrt${'q' * (length - 'lnbcrt'.length)}';

/// A realistic bolt11 invoice: bech32 payload, 383 characters long.
String bolt11Invoice() {
  final buffer = StringBuffer('lnbcrt1');
  while (buffer.length < 383) {
    buffer.write(_bech32);
  }
  return buffer.toString().substring(0, 383);
}

/// A realistic 64-character transaction id.
String txid() {
  final buffer = StringBuffer();
  while (buffer.length < 64) {
    buffer.write(_hex);
  }
  return buffer.toString().substring(0, 64);
}

/// The visible truncation: [keep] characters from each end around the ellipsis.
String expected(int keep, String data) =>
    '${data.substring(0, keep)}…${data.substring(data.length - keep)}';

/// Lays [text] out the way the widget does, with the real font.
double layoutWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The previous fit: one-character-at-a-time shrink, kept as the oracle the
/// bounded search has to reproduce.
String linearFit(String data, TextStyle style, double maxWidth) {
  if (data.isEmpty) return data;
  if (layoutWidth(data, style) <= maxWidth) return data;

  const separator = '…';
  const minChars = 5;

  if (data.length <= minChars * 2) return data;

  final maxSide = (data.length - 1) ~/ 2;
  for (var keep = maxSide; keep >= minChars; keep--) {
    final truncated =
        '${data.substring(0, keep)}$separator'
        '${data.substring(data.length - keep)}';
    if (layoutWidth(truncated, style) <= maxWidth) return truncated;
  }

  return '${data.substring(0, minChars)}$separator'
      '${data.substring(data.length - minChars)}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The style the viewer renders a value with: the theme's body role, which is
  // Golos Text, at the weight the viewer copies in.
  final themeStyle = BullTypography.standard.body.copyWith(
    fontWeight: FontWeight.w500,
  );

  // Content widths a one-line value gets on a phone, from a narrow card up to
  // a full-width screen.
  const availableWidths = <double>[112, 144, 200, 288, 344, 420];

  setUpAll(() async {
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('../../assets/fonts/GolosText.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  test('truncates a long invoice within a bounded number of measurements', () {
    final data = invoiceOf(383);
    var measures = 0;

    final fitted = BullValueViewer.fitToWidth(
      data,
      themeStyle,
      400,
      measure: (text, s) {
        measures++;
        return measureChars(text, s);
      },
    );

    // 400 / 10 = 40 characters: '…' plus 19 characters on each side.
    expect(fitted, expected(19, data));
    expect(fitted.length, 39);
    expect(measureChars(fitted, themeStyle), lessThanOrEqualTo(400));
    // Each measurement is a synchronous one-line text layout on the UI thread,
    // so the count is what a frame pays. Keeping 19 of every 191 possible
    // characters shrinks linearly to ~170 layouts; the bounded search costs one
    // whole-value layout plus log2(191) ≈ 8, measured at nine in total.
    expect(measures, lessThanOrEqualTo(9));
  });

  test('searches a transaction id in a bounded number of measurements', () {
    final data = txid();
    var measures = 0;

    final fitted = BullValueViewer.fitToWidth(
      data,
      themeStyle,
      200,
      measure: (text, s) {
        measures++;
        return measureChars(text, s);
      },
    );

    // 200 / 10 = 20 characters: '…' plus 9 characters on each side.
    expect(fitted, expected(9, data));
    // 64 characters give 31 possible keeps, a quarter of the invoice's range,
    // so the search takes five layouts and the whole-value one makes six.
    expect(measures, lessThanOrEqualTo(6));
  });

  test('keeps the payload untouched when it already fits', () {
    final data = invoiceOf(383);
    var measures = 0;

    final fitted = BullValueViewer.fitToWidth(
      data,
      themeStyle,
      4000,
      measure: (text, s) {
        measures++;
        return measureChars(text, s);
      },
    );

    expect(fitted, data);
    expect(measures, 1);
  });

  test('keeps the two short ends when nothing wider fits', () {
    final data = invoiceOf(383);

    final fitted = BullValueViewer.fitToWidth(
      data,
      themeStyle,
      90,
      measure: measureChars,
    );

    expect(fitted, expected(5, data));
    expect(fitted.length, 11);
  });

  test('returns the widest truncation that fits', () {
    final data = invoiceOf(383);

    // The last width fits the whole value, so the already-fits branch is
    // asserted too instead of being skipped.
    for (final maxWidth in <double>[
      120,
      240,
      400,
      620,
      900,
      1200,
      1900,
      3830,
    ]) {
      final fitted = BullValueViewer.fitToWidth(
        data,
        themeStyle,
        maxWidth,
        measure: measureChars,
      );
      expect(
        measureChars(fitted, themeStyle),
        lessThanOrEqualTo(maxWidth),
        reason: 'maxWidth $maxWidth',
      );
      if (fitted == data) continue;

      final keep = (fitted.length - 1) ~/ 2;
      expect(fitted, expected(keep, data), reason: 'maxWidth $maxWidth');
      if (keep < (data.length - 1) ~/ 2) {
        expect(
          measureChars(expected(keep + 1, data), themeStyle),
          greaterThan(maxWidth),
          reason:
              'a wider truncation should not have fit at maxWidth '
              '$maxWidth',
        );
      }
    }
  });

  test('keeps the short ends at three small widths', () {
    final data = invoiceOf(383);

    // 11 characters cost 110: below it nothing fits, at it exactly the minimum
    // fits, and one step above widens the truncation by one.
    const smallWidths = <double>[90, 110, 130];
    for (final maxWidth in smallWidths) {
      var measures = 0;
      final fitted = BullValueViewer.fitToWidth(
        data,
        themeStyle,
        maxWidth,
        measure: (text, s) {
          measures++;
          return measureChars(text, s);
        },
      );
      final oracle = linearFit(data, themeStyle, maxWidth);

      expect(fitted, oracle, reason: 'maxWidth $maxWidth');
      expect(
        fitted,
        expected(maxWidth >= 130 ? 6 : 5, data),
        reason: 'maxWidth $maxWidth',
      );
      // One whole-value layout and seven search layouts, whatever the width.
      expect(measures, lessThanOrEqualTo(8), reason: 'maxWidth $maxWidth');
      if (maxWidth >= 110) {
        expect(
          measureChars(fitted, themeStyle),
          lessThanOrEqualTo(maxWidth),
          reason: 'maxWidth $maxWidth',
        );
      }
    }
  });

  test('matches the previous linear fit on the theme font', () {
    for (final data in <String>[bolt11Invoice(), txid()]) {
      for (final maxWidth in availableWidths) {
        expect(
          BullValueViewer.fitToWidth(data, themeStyle, maxWidth),
          linearFit(data, themeStyle, maxWidth),
          reason: '${data.length} characters at maxWidth $maxWidth',
        );
      }
    }
  });

  test('a wider truncation is never narrower for an ascii identifier', () {
    // The bounded search relies on this property; pin it to the shipped font so
    // a font change that breaks it fails here instead of truncating oddly.
    for (final data in <String>[bolt11Invoice(), txid()]) {
      final maxSide = (data.length - 1) ~/ 2;
      var narrowestWider = 0.0;
      for (var keep = 5; keep <= maxSide; keep++) {
        final width = layoutWidth(expected(keep, data), themeStyle);
        expect(
          width,
          greaterThanOrEqualTo(narrowestWider),
          reason: 'keep $keep of ${data.length} characters',
        );
        narrowestWider = width;
      }
    }
  });

  test('keeps the linear scan for values that are not ascii', () {
    final data = 'lnbc${'🟠' * 120}e\u0301';
    for (final maxWidth in <double>[120, 200, 288]) {
      expect(
        BullValueViewer.fitToWidth(data, themeStyle, maxWidth),
        linearFit(data, themeStyle, maxWidth),
        reason: 'maxWidth $maxWidth',
      );
    }
  });
}
