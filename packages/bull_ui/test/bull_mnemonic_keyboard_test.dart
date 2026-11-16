import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

Future<void> pumpKeyboard(
  WidgetTester tester, {
  required Set<String> enabledLetters,
  bool canBackspace = true,
  bool canAdvance = true,
  void Function(String)? onLetter,
  VoidCallback? onBackspace,
  VoidCallback? onEnter,
  VoidCallback? onToggleShuffle,
  List<String> layout = BullMnemonicKeyboard.qwerty,
  bool scrollable = false,
}) async {
  await tester.pumpWidget(
    wrapWithTheme(
      BullMnemonicKeyboard(
        enabledLetters: enabledLetters,
        canBackspace: canBackspace,
        canAdvance: canAdvance,
        onLetter: onLetter ?? (_) {},
        onBackspace: onBackspace ?? () {},
        onEnter: onEnter ?? () {},
        shuffleActive: false,
        onToggleShuffle: onToggleShuffle ?? () {},
        shuffleHint: 'shuffle',
        layout: layout,
        scrollable: scrollable,
      ),
    ),
  );
}

void main() {
  group('BullMnemonicKeyboard', () {
    testWidgets('renders every letter of the alphabet as a key', (
      tester,
    ) async {
      await pumpKeyboard(tester, enabledLetters: const {});
      for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        expect(find.text(letter), findsOneWidget, reason: 'missing $letter');
      }
    });

    testWidgets('an enabled key reports its letter', (tester) async {
      String? tapped;
      await pumpKeyboard(
        tester,
        enabledLetters: const {'a'},
        onLetter: (l) => tapped = l,
      );

      await tester.tap(find.text('a'));
      expect(tapped, equals('a'));
    });

    testWidgets('a disabled key does nothing when tapped', (tester) async {
      var fired = false;
      await pumpKeyboard(
        tester,
        enabledLetters: const {'a'}, // 'b' is disabled
        onLetter: (_) => fired = true,
      );

      await tester.tap(find.text('b'), warnIfMissed: false);
      expect(fired, isFalse);
    });

    testWidgets('backspace reports when enabled', (tester) async {
      var fired = false;
      await pumpKeyboard(
        tester,
        enabledLetters: const {},
        onBackspace: () => fired = true,
      );

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(fired, isTrue);
    });

    testWidgets('backspace does nothing when disabled', (tester) async {
      var fired = false;
      await pumpKeyboard(
        tester,
        enabledLetters: const {},
        canBackspace: false,
        onBackspace: () => fired = true,
      );

      await tester.tap(
        find.byIcon(Icons.backspace_outlined),
        warnIfMissed: false,
      );
      expect(fired, isFalse);
    });

    testWidgets('enter reports when enabled', (tester) async {
      var fired = false;
      await pumpKeyboard(
        tester,
        enabledLetters: const {},
        onEnter: () => fired = true,
      );

      await tester.tap(find.byIcon(Icons.keyboard_return));
      expect(fired, isTrue);
    });

    testWidgets('enter does nothing while the word is unfinished', (
      tester,
    ) async {
      var fired = false;
      await pumpKeyboard(
        tester,
        enabledLetters: const {},
        canAdvance: false,
        onEnter: () => fired = true,
      );

      await tester.tap(find.byIcon(Icons.keyboard_return), warnIfMissed: false);
      expect(fired, isFalse);
    });
  });

  testWidgets('a scrollable grid exposes no key count or extent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final layout = [
        for (var i = 0; i < 300; i++) String.fromCharCode(0x4e00 + i),
      ];
      await pumpKeyboard(
        tester,
        enabledLetters: layout.toSet(),
        layout: layout,
        scrollable: true,
      );
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.scrollChildCount != null ||
              node.scrollIndex != null ||
              node.scrollExtentMax != null,
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel(layout.first), findsNothing);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a combining mark key shows a base and reports the bare mark', (
    tester,
  ) async {
    String? tapped;
    await pumpKeyboard(
      tester,
      enabledLetters: const {'\u0301'},
      layout: const ['\u0301'],
      scrollable: true,
      onLetter: (letter) => tapped = letter,
    );
    expect(find.text('\u0301'), findsNothing);
    await tester.tap(find.text('\u25CC\u0301'));
    expect(tapped, '\u0301');
  });
}
