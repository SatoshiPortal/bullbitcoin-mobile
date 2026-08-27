import 'package:bb_mobile/core/widgets/mnemonic_keyboard.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpKeyboard(
  WidgetTester tester, {
  required Set<String> enabledLetters,
  bool canBackspace = true,
  bool canAdvance = true,
  void Function(String)? onLetter,
  VoidCallback? onBackspace,
  VoidCallback? onEnter,
  VoidCallback? onToggleShuffle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MnemonicKeyboard(
          enabledLetters: enabledLetters,
          canBackspace: canBackspace,
          canAdvance: canAdvance,
          onLetter: onLetter ?? (_) {},
          onBackspace: onBackspace ?? () {},
          onEnter: onEnter ?? () {},
          shuffleActive: false,
          onToggleShuffle: onToggleShuffle ?? () {},
          shuffleHint: 'shuffle',
        ),
      ),
    ),
  );
}

void main() {
  group('MnemonicKeyboard', () {
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
}
