import 'package:bb_mobile/features/sp/presentation/scan_start_ticks.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('scanStartTicks', () {
    test('maps each offset to a height, ordered oldest to newest', () {
      final ticks = scanStartTicks(
        loc: loc,
        tip: 900000,
        minBirthday: 709632,
        blocksPerDay: 144,
      );

      expect(ticks, const [
        (label: 'Earliest', height: 709632),
        (label: '1 year', height: 847440),
        (label: '6 months', height: 874080),
        (label: '5 months', height: 878400),
        (label: '4 months', height: 882720),
        (label: '3 months', height: 887040),
        (label: '2 months', height: 891360),
        (label: '1 month', height: 895680),
        (label: '3 weeks', height: 896976),
        (label: '2 weeks', height: 897984),
        (label: '1 week', height: 898992),
      ]);
    });

    test('drops offsets that fall at or below the birthday on a short chain',
        () {
      final ticks = scanStartTicks(
        loc: loc,
        tip: 709700,
        minBirthday: 709632,
        blocksPerDay: 144,
      );

      expect(ticks, const [(label: 'Earliest', height: 709632)]);
    });
  });

  group('blocksToApproxDuration', () {
    String d(int blocks) =>
        blocksToApproxDuration(loc, blocks, blocksPerDay: 144);

    test('shows the two most-significant non-zero units', () {
      expect(d(144 * 365), '1 year');
      expect(d(100000), '1 year 10 months');
      expect(d(300), '2 days 2 hours');
      expect(d(20), '3 hours');
    });

    test('singular units drop the plural s', () {
      expect(d(150), '1 day 1 hour');
    });

    test('under an hour', () {
      expect(d(3), 'less than an hour');
      expect(d(0), 'less than an hour');
    });
  });
}
