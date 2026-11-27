import 'package:bull_ui/src/data_display/bull_value_viewer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Width of any truncation under [measureChars]: one unit per character.
const double _charWidth = 10;

double measureChars(String text, TextStyle style) => text.length * _charWidth;

/// A Lightning invoice is a single unbreakable token; this is its length class
/// (383 characters for the regtest invoice measured on the Galaxy S10e).
String invoiceOf(int length) => 'lnbcrt${'q' * (length - 'lnbcrt'.length)}';

String expected(int keep, String data) =>
    '${data.substring(0, keep)}…${data.substring(data.length - keep)}';

void main() {
  const style = TextStyle(fontSize: 14);

  test('truncates a long invoice within a bounded number of measurements', () {
    final data = invoiceOf(383);
    var measures = 0;

    final fitted = BullValueViewer.fitToWidth(
      data,
      style,
      400,
      measure: (text, s) {
        measures++;
        return measureChars(text, s);
      },
    );

    // 400 / 10 = 40 characters: '…' plus 19 characters on each side.
    expect(fitted, expected(19, data));
    expect(fitted.length, 39);
    expect(measureChars(fitted, style), lessThanOrEqualTo(400));
    // Each measurement is a synchronous one-line text layout on the UI thread,
    // so the count is what a frame pays. Keeping 19 of every 191 possible
    // characters shrinks linearly to ~170 layouts; a bounded search costs
    // log2(191) ≈ 8.
    expect(measures, lessThanOrEqualTo(12));
  });

  test('keeps the payload untouched when it already fits', () {
    final data = invoiceOf(383);
    var measures = 0;

    final fitted = BullValueViewer.fitToWidth(
      data,
      style,
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
      style,
      90,
      measure: measureChars,
    );

    expect(fitted, expected(5, data));
    expect(fitted.length, 11);
  });

  test('returns the widest truncation that fits', () {
    final data = invoiceOf(383);

    for (final maxWidth in <double>[120, 240, 400, 620, 900, 1200, 1900]) {
      final fitted = BullValueViewer.fitToWidth(
        data,
        style,
        maxWidth,
        measure: measureChars,
      );
      if (identical(fitted, data)) continue;
      final keep = (fitted.length - 1) ~/ 2;
      expect(
        measureChars(fitted, style),
        lessThanOrEqualTo(maxWidth),
        reason: 'maxWidth $maxWidth',
      );
      if (keep * 2 + 3 <= data.length) {
        expect(
          measureChars(expected(keep + 1, data), style),
          greaterThan(maxWidth),
          reason:
              'a wider truncation should not have fit at maxWidth '
              '$maxWidth',
        );
      }
    }
  });
}
