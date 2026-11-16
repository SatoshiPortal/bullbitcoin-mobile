import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// Screens and windows a keypad must fit, from cramped to roomy.
const smallPhone = Size(320, 568);
const largePhone = Size(430, 932);
const landscapePhone = Size(844, 390);
const desktopWindow = Size(1440, 900);

const grid = BullMnemonicKeyboard.grid;

BullKeypadMetrics resolve(Size screen) =>
    grid.resolve(BoxConstraints(maxWidth: screen.width), screen);

/// Pumps the mnemonic keyboard docked under an expanding body, as the import
/// screen does, on a screen of [size] logical pixels.
Future<void> pumpDocked(
  WidgetTester tester,
  Size size, {
  bool scrollable = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final layout = scrollable
      ? [for (var i = 0; i < 40; i++) String.fromCharCode(0x4e00 + i)]
      : BullMnemonicKeyboard.qwerty;
  await tester.pumpWidget(
    wrapWithTheme(
      Column(
        children: [
          const Expanded(child: SizedBox.expand()),
          BullMnemonicKeyboard(
            enabledLetters: layout.toSet(),
            canBackspace: true,
            canAdvance: true,
            onLetter: (_) {},
            onBackspace: () {},
            onEnter: () {},
            shuffleActive: false,
            onToggleShuffle: () {},
            shuffleHint: 'shuffle',
            layout: layout,
            scrollable: scrollable,
          ),
        ],
      ),
    ),
  );
}

Size enterKeySize(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('mnemonicEnterKey')));

void main() {
  group('BullKeypadGrid', () {
    test('keys grow with the screen height up to the cap', () {
      final heights = [
        for (final screen in [smallPhone, largePhone, const Size(1440, 1600)])
          resolve(screen).keyHeight,
      ];
      expect(heights[0], lessThan(heights[1]));
      expect(heights[1], lessThan(heights[2]));
      expect(heights[2], grid.maxKeyHeight);
    });

    test('the rows take a quarter of a phone screen height', () {
      final metrics = resolve(largePhone);
      final rows =
          metrics.keyHeight * grid.rows + metrics.gap * (grid.rows - 1);
      expect(rows, closeTo(largePhone.height * grid.screenShare, 0.01));
    });

    test('a wide window caps the key width and the keypad width', () {
      final metrics = resolve(desktopWindow);
      expect(metrics.keyWidth, grid.maxKeyWidth);
      expect(
        metrics.width,
        grid.columns * grid.maxKeyWidth + (grid.columns - 1) * grid.gap,
      );
    });

    test('a short window bounds the height, never below the floor', () {
      final landscape = resolve(landscapePhone);
      // The width alone would allow a taller key.
      expect(
        landscape.keyHeight,
        lessThan(landscape.keyWidth * grid.aspectRatio),
      );
      expect(landscape.keyHeight, greaterThanOrEqualTo(grid.minKeyHeight));
      final tiny = grid.resolve(
        const BoxConstraints(maxWidth: 200, maxHeight: 60),
        const Size(200, 60),
      );
      expect(tiny.keyHeight, grid.minKeyHeight);
    });

    test('a bounded parent height is a budget too', () {
      final free = resolve(largePhone);
      final bounded = grid.resolve(
        BoxConstraints(maxWidth: largePhone.width, maxHeight: 130),
        largePhone,
      );
      expect(bounded.keyHeight, lessThan(free.keyHeight));
    });
  });

  group('BullMnemonicKeyboard sizing', () {
    for (final (name, size) in [
      ('small phone', smallPhone),
      ('large phone', largePhone),
      ('landscape phone', landscapePhone),
      ('desktop window', desktopWindow),
    ]) {
      testWidgets('fits a $name without overflow', (tester) async {
        await pumpDocked(tester, size);
        expect(tester.takeException(), isNull);
        final keyboard = tester.getRect(find.byType(BullMnemonicKeyboard));
        expect(keyboard.bottom, lessThanOrEqualTo(size.height));
        final key = enterKeySize(tester);
        expect(
          key.height,
          inInclusiveRange(grid.minKeyHeight, grid.maxKeyHeight),
        );
      });
    }

    testWidgets('the grid of another script fits a landscape phone', (
      tester,
    ) async {
      await pumpDocked(tester, landscapePhone, scrollable: true);
      expect(tester.takeException(), isNull);
      final keyboard = tester.getRect(find.byType(BullMnemonicKeyboard));
      expect(keyboard.bottom, lessThanOrEqualTo(landscapePhone.height));
    });

    testWidgets('keys are taller on a large phone than on a small one', (
      tester,
    ) async {
      await pumpDocked(tester, smallPhone);
      final small = enterKeySize(tester).height;
      await pumpDocked(tester, largePhone);
      final large = enterKeySize(tester).height;
      expect(large, greaterThan(small));
    });
  });
}
