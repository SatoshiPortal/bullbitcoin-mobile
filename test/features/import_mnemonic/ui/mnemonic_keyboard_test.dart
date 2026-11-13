import 'package:bb_mobile/features/import_mnemonic/ui/widgets/mnemonic_keyboard.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

Future<void> pumpKeyboard(
  WidgetTester tester, {
  required Set<String> enabledLetters,
  bool canBackspace = true,
  bool canAdvance = true,
  void Function(String)? onLetter,
  VoidCallback? onBackspace,
  VoidCallback? onEnter,
  VoidCallback? onToggleShuffle,
  List<String> layout = MnemonicKeyboard.qwerty,
  bool scrollable = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
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
          layout: layout,
          scrollable: scrollable,
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

  group('MnemonicKeyboard.keyLabel', () {
    for (final language in bip39.Language.values) {
      test('${language.name} keys never share a label', () {
        final characters = {
          for (final word in language.list) ...nfkd(word).split(''),
        };
        final labels = {
          for (final character in characters)
            MnemonicKeyboard.keyLabel(character),
        };
        expect(labels, hasLength(characters.length));
      });
    }

    test('initial consonants and vowels show their compatibility jamo', () {
      for (final code in [
        for (var c = 0x1100; c <= 0x1112; c++) c,
        for (var c = 0x1161; c <= 0x1175; c++) c,
      ]) {
        final value = String.fromCharCode(code);
        final label = MnemonicKeyboard.keyLabel(value);
        expect(label, isNot(value));
        // Compatibility jamo decompose back to the conjoining initial/vowel.
        expect(nfkd(label), value);
      }
    });

    test('final consonants are drawn on a dotted circle', () {
      for (var code = 0x11A8; code <= 0x11C2; code++) {
        final label = MnemonicKeyboard.keyLabel(String.fromCharCode(code));
        expect(label.runes.first, 0x25CC);
        expect(label.runes, hasLength(2));
      }
    });

    test('plain letters and Han characters are shown unchanged', () {
      for (final value in ['a', 'z', '\u3042', '\u7684']) {
        expect(MnemonicKeyboard.keyLabel(value), value);
      }
    });
  });
}
