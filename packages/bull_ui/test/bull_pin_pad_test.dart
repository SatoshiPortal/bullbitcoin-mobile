import 'dart:ui' show SemanticsAction, Tristate;
import 'dart:math';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:flutter/services.dart';
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
    testWidgets('names every key and exposes enabled and scramble states', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        await pumpPad(tester);
        final padContext = tester.element(find.byType(BullPinPad));
        final deleteLabel = MaterialLocalizations.of(padContext)
            .deleteButtonTooltip;
        final labels = [
          'scramble',
          deleteLabel,
          for (var i = 0; i < 10; i++) '$i',
        ];
        void expectKeys({required bool enabled}) {
          for (final label in labels) {
            final keys = find.semantics.byPredicate(
              (node) => node.label == label && node.flagsCollection.isButton,
            );
            expect(keys, findsOne, reason: label);
            final key = keys.evaluate().single;
            expect(
              key.flagsCollection.isEnabled,
              enabled ? Tristate.isTrue : Tristate.isFalse,
            );
            expect(
              key.getSemanticsData().hasAction(SemanticsAction.tap),
              enabled,
            );
            expect(key.rect.width, greaterThanOrEqualTo(48));
            expect(key.rect.height, greaterThanOrEqualTo(48));
          }
        }

        expectKeys(enabled: true);
        await tester.tap(scrambleKey);
        await tester.pump();
        expect(
          tester.getSemantics(scrambleKey).flagsCollection.isToggled,
          Tristate.isTrue,
        );

        await pumpPad(tester, enabled: false);
        expectKeys(enabled: false);
      } finally {
        semantics.dispose();
      }
    });

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
      expect(icon.color, testBullTheme.text);
    });

    // The unlock screen locks the pad during a failed-attempt timeout; a tap
    // must not enter a digit then.
    testWidgets('every tap vibrates, a disabled key does not', (tester) async {
      final clicks = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            clicks.add(call.arguments as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpPad(tester);
      await tester.tap(find.text('7'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.tap(scrambleKey);
      expect(clicks, List.filled(3, 'HapticFeedbackType.selectionClick'));

      clicks.clear();
      await pumpPad(tester, enabled: false);
      await tester.tap(find.text('7'));
      expect(clicks, isEmpty);
    });

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
      // A disabled key has no fill.
      expect(keyFill(tester, find.text('7')), testBullTheme.transparent);
      expect(
        keyFill(tester, find.byIcon(Icons.shuffle)),
        testBullTheme.transparent,
      );
    });

    testWidgets('digits sit in outlined keys, the icons are bare', (
      tester,
    ) async {
      await pumpPad(tester);
      final sevenKey = find.ancestor(
        of: find.text('7'),
        matching: find.byType(BullKeyCap),
      );
      expect(
        tester.widget<BullKeyCap>(sevenKey).borderColor,
        testBullTheme.text,
      );
      for (final glyph in [
        find.text('7'),
        find.byIcon(Icons.backspace_outlined),
        find.byIcon(Icons.shuffle),
      ]) {
        expect(keyFill(tester, glyph), testBullTheme.transparent);
      }
      final seven = tester.widget<Text>(find.text('7')).style;
      expect(seven?.color, testBullTheme.text);
      expect(seven?.fontWeight, FontWeight.w500);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.backspace_outlined)).color,
        testBullTheme.text,
      );
    });

    testWidgets('a held digit fills, and a reshuffle clears it at once', (
      tester,
    ) async {
      InkWell ink() => tester.widget<InkWell>(
        find.ancestor(of: find.text('5'), matching: find.byType(InkWell)).first,
      );
      Material fillOf(Finder glyph) => tester.widget<Material>(
        find.ancestor(of: glyph, matching: find.byType(Material)).first,
      );
      await pumpPad(tester);
      expect(ink().highlightColor, testBullTheme.surfaceContainerHighest);
      expect(ink().splashFactory, NoSplash.splashFactory);
      await tester.tap(scrambleKey);
      await tester.pump();
      expect(ink().highlightColor, testBullTheme.surfaceContainerHighest);

      // Tapping a scrambled key rebuilds every key, so no InkWell keeps the
      // fill of the slot just pressed.
      final before = tester.element(
        find.ancestor(of: find.text('5'), matching: find.byType(InkWell)).first,
      );
      await tester.tap(find.text('5'));
      await tester.pump();
      final after = tester.element(
        find.ancestor(of: find.text('5'), matching: find.byType(InkWell)).first,
      );
      expect(identical(before, after), isFalse);
      expect(fillOf(find.text('5')).color, testBullTheme.transparent);
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
