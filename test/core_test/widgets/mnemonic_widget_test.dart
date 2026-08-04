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

Future<void> pumpWidget(
  WidgetTester tester, {
  bip39.MnemonicLength length = bip39.MnemonicLength.words12,
  bool allowAutoFillWords = false,
  bool allowMultipleMnemonicLength = true,
  String? externalError,
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
            externalError: externalError,
          ),
        ),
      ),
    ),
  );
}

Finder wordField(int index) => find.byType(TextField).at(index);

Future<void> fillAll(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    await tester.enterText(wordField(i), words[i]);
  }
  await tester.pump();
}

/// The color of the square index badge of field [index] - the widget that
/// answers "is this word acceptable".
Color badgeColor(WidgetTester tester, int index) {
  final displayIndex = index + 1;
  final label = displayIndex < 10 ? '0$displayIndex' : '$displayIndex';
  final badge = tester.widget<Container>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 34 &&
                widget.constraints?.maxHeight == 34,
          ),
        )
        .first,
  );
  return (badge.decoration! as BoxDecoration).color!;
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

    testWidgets('renders a caller-owned external error above the button', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        onSubmit: (_) {},
        externalError: 'A label is required to import a mnemonic',
      );

      // Shown without any submit, and stays put (persisted by the caller),
      // unlike a one-shot snackbar.
      expect(
        find.text('A label is required to import a mnemonic'),
        findsOneWidget,
      );
    });

    testWidgets('a local entry error takes precedence over the external one', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        onSubmit: (_) {},
        externalError: 'external error message',
      );

      // Submitting an incomplete sentence raises a local entry error, which is
      // the more relevant message and must win.
      await fillAll(tester, [...validWords.take(11), '']);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.text('Enter all words of your mnemonic'), findsOneWidget);
      expect(find.text('external error message'), findsNothing);
    });

    testWidgets('reports an invalid checksum without echoing the word', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      await fillAll(tester, [...validWords.take(11), 'zoo']);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(
        find.text(
          'This recovery phrase is not valid. '
          'A word is either mistyped or out of order.',
        ),
        findsOneWidget,
      );
      // bip39_mnemonic raises 'Mnemonic checksum zoo is invalid'. That message
      // carries a word of the user's seed, so none of it may reach the screen.
      expect(find.textContaining('checksum'), findsNothing);
    });

    testWidgets('reports an unknown word without echoing it', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});

      // 'zzzz' is not in the english wordlist.
      await fillAll(tester, [...validWords.take(11), 'zzzz']);
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(
        find.text(
          'Some words are not in the recovery word list '
          '— the red numbers show which.',
        ),
        findsOneWidget,
      );
      // The typed field legitimately shows 'zzzz'; the failure message must
      // not. Only plain Text widgets are checked, not the EditableText inputs.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains('zzzz') == true,
        ),
        findsNothing,
      );
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

    testWidgets('hides the count once the last word is complete', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      await tester.tap(wordField(11));
      await tester.pump();
      expect(find.text('128 possible last words'), findsOneWidget);

      await tester.enterText(wordField(11), 'sen');
      await tester.pump();
      await tester.tap(find.text('senior'));
      await tester.pump();

      // The question is answered: like the chips, the label leaves.
      expect(find.textContaining('possible last words'), findsNothing);
    });

    testWidgets('tapping a chip on the last field dismisses the keyboard', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      await tester.tap(wordField(11));
      await tester.pump();
      await tester.enterText(wordField(11), 'sen');
      await tester.pump();
      await tester.tap(find.text('senior'));
      await tester.pump();

      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        equals('senior'),
      );
      // A tapped chip completes the sentence, like the auto fill: the same
      // natural moment to dismiss the keyboard.
      expect(
        tester.widget<TextField>(wordField(11)).focusNode!.hasFocus,
        isFalse,
      );
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

    testWidgets('does not auto fill the last field from the candidates', (
      tester,
    ) async {
      // A transcription error that is itself a valid word: shell -> sell.
      // The real last word 'senior' is then not a candidate, but 'se' singles
      // out exactly one candidate. Completing to it would produce a sentence
      // with a valid checksum, silently accepting the wrong mnemonic.
      final typed = [...validWords.take(11)];
      typed[3] = 'sell';
      final candidates = bip39.Mnemonic.lastWordCandidates(words: typed);
      final trap = candidates.where((w) => w.startsWith('se')).toList();
      expect(trap, hasLength(1), reason: 'the trap must exist to be tested');
      expect(trap.first, isNot('senior'));

      Mnemonic? submitted;
      await pumpWidget(
        tester,
        onSubmit: (m) => submitted = m,
        allowAutoFillWords: true,
      );
      await fillAll(tester, [...typed, '']);
      await tester.tap(wordField(11));
      await tester.pump();
      await tester.enterText(wordField(11), 'se');
      await tester.pump();

      // the field keeps what the user typed
      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        equals('se'),
      );

      // and the wrong sentence is never submitted
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(submitted, isNull);
    });

    testWidgets('still completes the real last word, then fails the checksum', (
      tester,
    ) async {
      // Same typo as above. 'seni' is unique in the wordlist ('senior') but
      // matches no candidate, so the user must still get their word - and the
      // checksum must then surface the typo instead of absorbing it.
      final typed = [...validWords.take(11)];
      typed[3] = 'sell';

      var submitted = false;
      await pumpWidget(
        tester,
        onSubmit: (_) => submitted = true,
        allowAutoFillWords: true,
      );
      await fillAll(tester, [...typed, '']);
      await tester.tap(wordField(11));
      await tester.pump();
      await tester.enterText(wordField(11), 'seni');
      await tester.pump();

      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        equals('senior'),
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(submitted, isFalse);
      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        isEmpty,
        reason: 'an invalid checksum clears the last word',
      );
    });

    testWidgets('refreshes the candidates when another field is cleared', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);
      await tester.tap(wordField(11));
      await tester.pump();
      expect(find.text('128 possible last words'), findsOneWidget);

      // Clearing an earlier word does not move focus, yet it invalidates the
      // candidate pool: the label must fall back, not keep a stale count.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(find.textContaining('possible last words'), findsNothing);
    });

    testWidgets('auto fills once the prefix leaves a single candidate', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await tester.tap(wordField(0));
      await tester.pump();
      // 'aba' can only be 'abandon'.
      await tester.enterText(wordField(0), 'aba');
      await tester.pump();

      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('abandon'),
      );
      // The completion was the only possibility left: the field locks, but
      // focus stays put and the keyboard stays up - no automatic advance.
      expect(
        tester.widget<TextField>(wordField(0)).focusNode!.hasFocus,
        isTrue,
      );

      // A stray keystroke is swallowed instead of breaking the word.
      await tester.enterText(wordField(0), 'abandonx');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('abandon'),
      );
    });

    testWidgets('the clear icon unlocks an auto-filled field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await tester.tap(wordField(0));
      await tester.pump();
      await tester.enterText(wordField(0), 'aba');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('abandon'),
      );

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(tester.widget<TextField>(wordField(0)).controller!.text, isEmpty);

      // Editable again right away, focus never left: 'abi' -> 'ability'.
      await tester.enterText(wordField(0), 'abi');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('ability'),
      );
      expect(
        tester.widget<TextField>(wordField(0)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('backspace on an auto-filled word empties and unlocks it', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await tester.tap(wordField(0));
      await tester.pump();
      await tester.enterText(wordField(0), 'aba');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('abandon'),
      );

      // A deletion is the user's undo instinct: the field empties (as the
      // clear icon would) instead of ignoring the keystroke.
      await tester.enterText(wordField(0), 'abando');
      await tester.pump();
      expect(tester.widget<TextField>(wordField(0)).controller!.text, isEmpty);
      expect(
        tester.widget<TextField>(wordField(0)).focusNode!.hasFocus,
        isTrue,
      );

      // Unlocked: typing completes again.
      await tester.enterText(wordField(0), 'abi');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(0)).controller!.text,
        equals('ability'),
      );
    });

    testWidgets('marks a last word that cannot close the checksum as wrong', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      // Reference colors from the first field: unknown word, then valid word.
      await tester.enterText(wordField(0), 'zzzz');
      await tester.pump();
      final invalidColor = badgeColor(tester, 0);
      await tester.enterText(wordField(0), validWords.first);
      await tester.pump();
      final validColor = badgeColor(tester, 0);

      await tester.tap(wordField(11));
      await tester.pump();

      // 'zoo' is a wordlist word, but not one of this sentence's checksum
      // candidates: on the last field that makes it the wrong word.
      await tester.enterText(wordField(11), 'zoo');
      await tester.pump();
      expect(badgeColor(tester, 11), equals(invalidColor));

      // The real last word is both a wordlist word and a candidate.
      await tester.enterText(wordField(11), 'senior');
      await tester.pump();
      expect(badgeColor(tester, 11), equals(validColor));
    });

    testWidgets('only the last word dismisses the keyboard', (tester) async {
      // shell -> sell keeps every word valid but moves the checksum.
      final typed = [...validWords.take(11)];
      typed[3] = 'sell';

      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);
      await fillAll(tester, [...typed, '']);
      await tester.tap(wordField(11));
      await tester.pump();
      await tester.enterText(wordField(11), 'seni');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        equals('senior'),
      );
      // The sentence is complete: the one place the keyboard may go.
      expect(
        tester.widget<TextField>(wordField(11)).focusNode!.hasFocus,
        isFalse,
      );

      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Cleared by the parent on the checksum failure: editable again, so
      // the word can be retyped.
      expect(tester.widget<TextField>(wordField(11)).controller!.text, isEmpty);
      await tester.enterText(wordField(11), 'seni');
      await tester.pump();
      expect(
        tester.widget<TextField>(wordField(11)).controller!.text,
        equals('senior'),
      );
    });
  });
}
