import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Screens and windows a keypad must fit, from cramped to roomy.
const smallPhone = Size(320, 568);
const largePhone = Size(430, 932);
const landscapePhone = Size(844, 390);
const desktopWindow = Size(1440, 900);

/// A keypad grid shaped like a letter keyboard: ten keys across, three rows.
const grid = BullKeypadGrid(
  columns: 10,
  rows: 3,
  aspectRatio: 3,
  minKeyHeight: 40,
  maxKeyHeight: 80,
  maxKeyWidth: 72,
  gap: 4,
  screenShare: 0.25,
  maxGlyphSize: 30,
);

BullKeypadMetrics resolve(Size screen) =>
    grid.resolve(BoxConstraints(maxWidth: screen.width), screen);

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
}
