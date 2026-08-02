import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid 12 word sentence, used so submitting exercises the real checksum.
const validWords = [
  'raise',
  'beach',
  'verb',
  'shell',
  'soft',
  'tumble',
  'satoshi',
  'wink',
  'clown',
  'enjoy',
  'more',
  'senior',
];

Future<Mnemonic?> pumpWidget(
  WidgetTester tester, {
  bip39.MnemonicLength length = bip39.MnemonicLength.words12,
  bool allowAutoFillWords = false,
  bool allowMultipleMnemonicLength = true,
  required void Function(Mnemonic) onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MnemonicWidget(
            initialLength: length,
            onSubmit: onSubmit,
            allowAutoFillWords: allowAutoFillWords,
            allowMultipleMnemonicLength: allowMultipleMnemonicLength,
            allowLabel: false,
            allowPassphrase: false,
          ),
        ),
      ),
    ),
  );
  return null;
}

Finder wordField(int index) => find.byType(TextField).at(index);

Future<void> fillAll(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    await tester.enterText(wordField(i), words[i]);
  }
  await tester.pump();
}

void main() {
  group('MnemonicWidget', () {
    testWidgets('renders 12 fields for a 12 word sentence', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      expect(find.byType(TextField), findsNWidgets(12));
    });

    testWidgets('renders 24 fields for a 24 word sentence', (tester) async {
      await pumpWidget(
        tester,
        length: bip39.MnemonicLength.words24,
        onSubmit: (_) {},
      );
      expect(find.byType(TextField), findsNWidgets(24));
    });

    testWidgets('submits the typed sentence', (tester) async {
      Mnemonic? submitted;
      await pumpWidget(tester, onSubmit: (m) => submitted = m);

      await fillAll(tester, validWords);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted!.words, equals(validWords));
    });

    testWidgets('lowercases as the user types', (tester) async {
      Mnemonic? submitted;
      await pumpWidget(tester, onSubmit: (m) => submitted = m);

      await fillAll(tester, [
        validWords.first.toUpperCase(),
        ...validWords.skip(1),
      ]);
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('raise'),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(submitted!.words.first, equals('raise'));
    });

    testWidgets('clears the last word when the checksum is invalid', (
      tester,
    ) async {
      var submitted = false;
      await pumpWidget(tester, onSubmit: (_) => submitted = true);

      // 'zoo' is a valid word but breaks the checksum of this sentence.
      await fillAll(tester, [...validWords.take(11), 'zoo']);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(submitted, isFalse);
      expect(tester.widget<TextField>(wordField(11)).controller!.text, isEmpty);
    });

    testWidgets('refuses to submit an incomplete sentence', (tester) async {
      var submitted = false;
      await pumpWidget(tester, onSubmit: (_) => submitted = true);

      await fillAll(tester, [...validWords.take(11), '']);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(submitted, isFalse);
      expect(find.text('Enter all words of your mnemonic'), findsOneWidget);
    });

    testWidgets('changing the length resets every field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, validWords);

      await tester.tap(find.byType(DropdownButton<bip39.MnemonicLength>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 words').last);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(24));
      for (var i = 0; i < 24; i++) {
        expect(
          tester.widget<TextField>(wordField(i)).controller!.text,
          isEmpty,
          reason: 'field $i should be empty after a length change',
        );
      }
    });
  });

  group('MnemonicWidget suggestions', () {
    testWidgets('suggests the words matching the focused prefix', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      await tester.tap(wordField(0));
      await tester.pump();
      await tester.enterText(wordField(0), 'zo');
      await tester.pump();

      // 'zone' and 'zoo' are the only english words starting with 'zo'.
      expect(find.text('zone'), findsOneWidget);
      expect(find.text('zoo'), findsOneWidget);
    });

    testWidgets('tapping a suggestion fills the focused field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});

      await tester.tap(wordField(0));
      await tester.pump();
      await tester.enterText(wordField(0), 'zo');
      await tester.pump();
      await tester.tap(find.text('zone'));
      await tester.pump();

      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('zone'),
      );
    });

    testWidgets('offers only checksum valid words on the last field', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      await tester.tap(wordField(11));
      await tester.pump();

      final valid = bip39.Mnemonic.lastWordCandidates(
        words: validWords.take(11).toList(),
      );
      expect(valid, hasLength(128));

      // Narrow to a prefix so the chips fit on screen: the list is lazy and
      // only builds what is visible.
      await tester.enterText(wordField(11), 'sen');
      await tester.pump();

      // the real last word is offered
      expect(find.text('senior'), findsOneWidget);

      // wordlist words with the same prefix that break the checksum are not
      final rejected = bip39.Language.english.list.where(
        (word) => word.startsWith('sen') && !valid.contains(word),
      );
      expect(rejected, isNotEmpty);
      for (final word in rejected) {
        expect(find.text(word), findsNothing, reason: '$word breaks checksum');
      }
    });

    testWidgets('announces how many last words are possible', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      await tester.tap(wordField(11));
      await tester.pump();

      expect(find.text('128 possible last words'), findsOneWidget);
    });

    testWidgets('falls back to the full list while earlier words are missing', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(10), '', '']);

      await tester.tap(wordField(11));
      await tester.pump();

      expect(find.textContaining('possible last words'), findsNothing);
    });

    testWidgets('auto fills once the prefix leaves a single candidate', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await tester.tap(wordField(0));
      await tester.pump();
      // 'zoo' is the only english word starting with 'zoo'.
      await tester.enterText(wordField(0), 'zoo');
      await tester.pump();

      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('zoo'),
      );
    });
  });
}
