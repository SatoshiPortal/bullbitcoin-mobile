import 'dart:math';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

final scrambleKey = find.byKey(const Key('pinPadScrambleToggle'));

const keypad = BullKeypadColors.light;

/// The colour a key is drawn with.
Color? keyFill(WidgetTester tester, Finder glyph) {
  final cap = find.ancestor(of: glyph, matching: find.byType(BullKeyCap));
  return tester
      .widget<Material>(
        find.descendant(of: cap, matching: find.byType(Material)).first,
      )
      .color;
}

Future<void> pumpPad(
  WidgetTester tester, {
  void Function(int)? onDigit,
  VoidCallback? onBackspace,
  bool enabled = true,
}) {
  return tester.pumpWidget(
    wrapWithTheme(
      BullPinPad(
        onDigit: onDigit ?? (_) {},
        onBackspace: onBackspace ?? () {},
        scrambleHint: 'scramble',
        enabled: enabled,
      ),
    ),
  );
}

/// The digits in reading order, each found exactly once.
List<int> layoutOf(WidgetTester tester) {
  final keys = [
    for (var digit = 0; digit < 10; digit++)
      (digit, tester.getCenter(find.text('$digit'))),
  ];
  keys.sort(
    (a, b) => a.$2.dy != b.$2.dy
        ? a.$2.dy.compareTo(b.$2.dy)
        : a.$2.dx.compareTo(b.$2.dx),
  );
  return [for (final (digit, _) in keys) digit];
}

void main() {
  group('BullPinPad', () {
    testWidgets('starts in the plain layout and reports taps', (tester) async {
      final digits = <int>[];
      var backspaces = 0;
      await pumpPad(
        tester,
        onDigit: digits.add,
        onBackspace: () => backspaces++,
      );

      expect(layoutOf(tester), BullPinPad.digits);
      await tester.tap(find.text('7'));
      await tester.tap(find.text('0'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(digits, [7, 0]);
      expect(backspaces, 1);
      expect(layoutOf(tester), BullPinPad.digits);
    });

    testWidgets('the scramble key shuffles every digit exactly once', (
      tester,
    ) async {
      await pumpPad(tester);
      await tester.tap(scrambleKey);
      await tester.pump();

      final layout = layoutOf(tester);
      expect(layout, isNot(BullPinPad.digits));
      expect(layout.toSet(), BullPinPad.digits.toSet());
      final icon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(icon.color, testBullTheme.primary);
    });

    testWidgets('a scrambled tap reports its digit, then reshuffles', (
      tester,
    ) async {
      final digits = <int>[];
      var backspaces = 0;
      await pumpPad(
        tester,
        onDigit: digits.add,
        onBackspace: () => backspaces++,
      );
      await tester.tap(scrambleKey);
      await tester.pump();

      for (final digit in [4, 2, 9]) {
        final before = layoutOf(tester);
        await tester.tap(find.text('$digit'));
        await tester.pump();
        expect(digits.last, digit);
        expect(layoutOf(tester), isNot(before));
      }
      final before = layoutOf(tester);
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(backspaces, 1);
      expect(layoutOf(tester), isNot(before));
      expect(digits, [4, 2, 9]);
    });

    testWidgets('turning scramble off restores the plain layout', (
      tester,
    ) async {
      await pumpPad(tester);
      await tester.tap(scrambleKey);
      await tester.pump();
      await tester.tap(scrambleKey);
      await tester.pump();

      expect(layoutOf(tester), BullPinPad.digits);
      final icon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(icon.color, keypad.onKey);
    });

    // The unlock screen locks the pad during a failed-attempt timeout; a tap
    // must not enter a digit then.
    testWidgets('ignores and dims every key while disabled', (tester) async {
      final digits = <int>[];
      var backspaces = 0;
      await pumpPad(
        tester,
        enabled: false,
        onDigit: digits.add,
        onBackspace: () => backspaces++,
      );

      await tester.tap(find.text('7'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.tap(scrambleKey);
      await tester.pump();

      expect(digits, isEmpty);
      expect(backspaces, 0);
      expect(layoutOf(tester), BullPinPad.digits);
      expect(
        tester.widget<Text>(find.text('7')).style?.color,
        keypad.disabledGlyph,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.backspace_outlined)).color,
        keypad.disabledGlyph,
      );
      // A disabled key has no fill and sinks into the panel.
      expect(keyFill(tester, find.text('7')), testBullTheme.transparent);
      expect(
        keyFill(tester, find.byIcon(Icons.shuffle)),
        testBullTheme.transparent,
      );
    });

    testWidgets('keys sit on the keypad panel, filled with the key colour', (
      tester,
    ) async {
      await pumpPad(tester);
      final panel = find.ancestor(
        of: find.text('7'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == keypad.panel,
        ),
      );
      expect(panel, findsOneWidget);
      expect(
        tester.getRect(panel).contains(tester.getCenter(scrambleKey)),
        isTrue,
      );
      expect(keyFill(tester, find.text('7')), keypad.key);
      expect(
        keyFill(tester, find.byIcon(Icons.backspace_outlined)),
        keypad.key,
      );
      expect(tester.widget<Text>(find.text('7')).style?.color, keypad.onKey);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.backspace_outlined)).color,
        keypad.onKey,
      );
    });

    testWidgets('digits ignore the system text size, the key already scales', (
      tester,
    ) async {
      await pumpPad(tester);
      final plain = tester.getSize(find.text('7'));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPad(tester);
      expect(tester.getSize(find.text('7')), plain);
      expect(
        tester.widget<Text>(find.text('7')).textScaler,
        TextScaler.noScaling,
      );
    });

    for (final (name, size) in [
      ('small phone', const Size(320, 568)),
      ('large phone', const Size(430, 932)),
      ('landscape phone', const Size(844, 390)),
      ('desktop window', const Size(1440, 900)),
    ]) {
      testWidgets('fits a $name without overflow', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          wrapWithTheme(
            Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                BullPinPad(
                  onDigit: (_) {},
                  onBackspace: () {},
                  scrambleHint: 'scramble',
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final pad = tester.getRect(find.byType(BullPinPad));
        expect(pad.bottom, lessThanOrEqualTo(size.height));
        final key = tester.getSize(scrambleKey);
        const grid = BullPinPad.grid;
        expect(
          key.height,
          inInclusiveRange(grid.minKeyHeight, grid.maxKeyHeight),
        );
        expect(key.width, lessThanOrEqualTo(grid.maxKeyWidth));
      });
    }
  });

  group('BullKeyScramble', () {
    test('returns every key, with few left in place', () {
      final random = Random(1);
      var previous = BullPinPad.digits;
      for (var i = 0; i < 200; i++) {
        final next = BullKeyScramble.next(
          BullPinPad.digits,
          previous: previous,
          maxUnmoved: 2,
          random: random,
        );
        expect(next.toSet(), BullPinPad.digits.toSet());
        var unmoved = 0;
        for (var slot = 0; slot < next.length; slot++) {
          if (next[slot] == previous[slot]) unmoved++;
        }
        expect(unmoved, lessThanOrEqualTo(2));
        previous = next;
      }
    });
  });
}
