import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/mnemonic_keyboard.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/foundation.dart';
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
  bool allowPassphrase = false,
  String? externalError,
  required void Function(Mnemonic) onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The passphrase field renders BullInputText, which reads the BullTheme
      // extension off the ambient ThemeData and throws without it.
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        // MnemonicWidget owns its own scroll and docks the keyboard, so it is
        // given bounded height (the test surface) rather than an outer scroll.
        body: MnemonicWidget(
          initialLength: length,
          onSubmit: onSubmit,
          allowAutoFillWords: allowAutoFillWords,
          allowMultipleMnemonicLength: allowMultipleMnemonicLength,
          allowLabel: false,
          allowPassphrase: allowPassphrase,
          externalError: externalError,
        ),
      ),
    ),
  );
}

Finder wordField(int index) => find.byType(TextField).at(index);

/// A key on the in-app keyboard, scoped so the letter is matched on the
/// keyboard and not in a field or a suggestion chip.
Finder keyboardKey(String letter) => find.descendant(
  of: find.byType(MnemonicKeyboard),
  matching: find.text(letter),
);

String fieldText(WidgetTester tester, int index) =>
    tester.widget<TextField>(wordField(index)).controller!.text;

bool fieldHasFocus(WidgetTester tester, int index) =>
    tester.widget<TextField>(wordField(index)).focusNode!.hasFocus;

/// Focuses a field. Read-only fields raise no OS keyboard; tapping them only
/// moves focus and reveals the docked in-app keyboard. A no-op when the field
/// already holds focus.
///
/// `pumpAndSettle` after each step because focusing a field triggers an
/// animated scroll (the widget keeps the focused field above the keyboard);
/// tapping before it settles would land on a moving target.
Future<void> focusField(WidgetTester tester, int index) async {
  if (fieldHasFocus(tester, index)) return;
  await tester.ensureVisible(wordField(index));
  await tester.pumpAndSettle();
  await tester.tap(wordField(index), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String letter) async {
  await tester.tap(keyboardKey(letter));
  await tester.pump();
}

Finder _backspaceKey() => find.descendant(
  of: find.byType(MnemonicKeyboard),
  matching: find.byIcon(Icons.backspace_outlined),
);

Finder shuffleToggle() => find.byKey(const Key('mnemonicParanoidToggle'));

/// The on-screen centre of every letter key currently rendered, keyed by
/// letter — used to detect that the layout changed (reshuffled) or held still.
Map<String, Offset> keyPositions(WidgetTester tester) {
  final positions = <String, Offset>{};
  for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
    final finder = keyboardKey(letter);
    if (finder.evaluate().isNotEmpty) {
      positions[letter] = tester.getCenter(finder);
    }
  }
  return positions;
}

/// Empties a field through the keyboard's backspace, one character at a time.
Future<void> clearField(WidgetTester tester, int index) async {
  await focusField(tester, index);
  while (fieldText(tester, index).isNotEmpty) {
    await tester.tap(_backspaceKey());
    await tester.pump();
  }
}

/// Types [word] into field [index] through the in-app keyboard, one key tap
/// per letter — the only input path now.
Future<void> typeWord(WidgetTester tester, int index, String word) async {
  await focusField(tester, index);
  for (final letter in word.split('')) {
    await tapKey(tester, letter);
  }
}

Future<void> fillAll(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    if (words[i].isEmpty) continue;
    await typeWord(tester, i, words[i]);
  }
  await tester.pump();
}

/// Dismisses the keyboard (so the submit button is no longer covered by the
/// bottom overlay) and taps it.
Future<void> submit(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Submit'));
  await tester.tap(find.text('Submit'));
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

    test('rejects a non-English language — the keyboard is a-z only', () {
      expect(
        () => MnemonicWidget(
          initialLength: bip39.MnemonicLength.words12,
          onSubmit: (_) {},
          language: bip39.Language.french,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('word fields are read-only so no OS keyboard can open', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      for (var i = 0; i < 12; i++) {
        expect(
          tester.widget<TextField>(wordField(i)).readOnly,
          isTrue,
          reason: 'field $i must be read-only',
        );
      }
    });

    testWidgets('the in-app keyboard appears only while a field is focused', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      expect(find.byType(MnemonicKeyboard), findsNothing);

      await focusField(tester, 0);
      expect(find.byType(MnemonicKeyboard), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(MnemonicKeyboard), findsNothing);
    });

    testWidgets('tapping empty page space dismisses the keyboard', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);
      expect(find.byType(MnemonicKeyboard), findsOneWidget);

      // Tap the gap between the two columns, level with the first field — a
      // point that lands on no field.
      final row = tester.getRect(wordField(0));
      await tester.tapAt(Offset(400, row.center.dy));
      await tester.pumpAndSettle();

      expect(find.byType(MnemonicKeyboard), findsNothing);
      expect(fieldHasFocus(tester, 0), isFalse);
    });

    testWidgets('submits the sentence typed on the in-app keyboard', (
      tester,
    ) async {
      Mnemonic? submitted;
      await pumpWidget(tester, onSubmit: (m) => submitted = m);

      await fillAll(tester, validWords);
      await submit(tester);

      expect(submitted, isNotNull);
      expect(submitted!.words, equals(validWords));
    });

    testWidgets('clears the last word when the checksum is invalid', (
      tester,
    ) async {
      var submitted = false;
      await pumpWidget(tester, onSubmit: (_) => submitted = true);

      // 'zoo' is a valid word but breaks the checksum of this sentence.
      await fillAll(tester, [...validWords.take(11), 'zoo']);
      await submit(tester);

      expect(submitted, isFalse);
      expect(fieldText(tester, 11), isEmpty);
    });

    testWidgets('refuses to submit an incomplete sentence', (tester) async {
      var submitted = false;
      await pumpWidget(tester, onSubmit: (_) => submitted = true);

      await fillAll(tester, [...validWords.take(11), '']);
      await submit(tester);

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

      await fillAll(tester, [...validWords.take(11), '']);
      await submit(tester);

      expect(find.text('Enter all words of your mnemonic'), findsOneWidget);
      expect(find.text('external error message'), findsNothing);
    });

    testWidgets('reports an invalid checksum without echoing the word', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      await fillAll(tester, [...validWords.take(11), 'zoo']);
      await submit(tester);

      expect(
        find.text(
          'This recovery phrase is not valid. '
          'A word is either mistyped or out of order.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('checksum'), findsNothing);
    });

    testWidgets('reports an incomplete word without echoing it', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      // 'aban' is a valid prefix the keyboard allows, but not a wordlist word:
      // the seed cannot be typed off-list, yet a half-typed word is still
      // caught as unknown on submit.
      await fillAll(tester, [...validWords.take(11), 'aban']);
      await submit(tester);

      expect(
        find.text(
          'Some words are not in the recovery word list '
          '— the red numbers show which.',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains('aban') == true,
        ),
        findsNothing,
      );
    });

    testWidgets('changing the length resets every field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, validWords);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<bip39.MnemonicLength>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 words').last);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(24));
      for (var i = 0; i < 24; i++) {
        expect(
          fieldText(tester, i),
          isEmpty,
          reason: 'field $i should be empty after a length change',
        );
      }
    });

    testWidgets(
      'shrinking the length with a late field focused does not crash',
      (tester) async {
        await pumpWidget(
          tester,
          length: bip39.MnemonicLength.words24,
          onSubmit: (_) {},
        );
        await focusField(tester, 23);

        // The crash interleaving, driven deterministically: the refocus of
        // field 23 and the length change land in the same frame. The focus
        // notification fires first, while the old 24-node list is still
        // installed, and schedules a post-frame scroll for index 23; the build
        // then replaces the list with 12 entries, and the scroll callback runs
        // after it. On device this interleaving comes from the dropdown popup
        // restoring focus to the word field in the same frame onChanged
        // rebuilds. The pump after the unfocus is required: without it the
        // unfocus and refocus coalesce into no notification at all.
        final node23 = tester.widget<TextField>(wordField(23)).focusNode!;
        final dropdown = tester.widget<DropdownButton<bip39.MnemonicLength>>(
          find.byType(DropdownButton<bip39.MnemonicLength>),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        node23.requestFocus();
        dropdown.onChanged!(bip39.MnemonicLength.words12);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNWidgets(12));
      },
    );
  });

  group('MnemonicWidget keyboard', () {
    testWidgets('offers no key that cannot continue a wordlist word', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'a');

      // No english word starts with 'aa', so 'a' must be disabled after 'a'.
      final aKey = tester.widget<InkWell>(
        find.ancestor(of: keyboardKey('a'), matching: find.byType(InkWell)),
      );
      expect(aKey.onTap, isNull);
    });

    testWidgets('tapping a disabled key does not change the field', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'a');

      await tester.tap(keyboardKey('a'), warnIfMissed: false);
      await tester.pump();
      expect(fieldText(tester, 0), equals('a'));
    });

    testWidgets('backspace clears the whole field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'abo'); // prefix of 'about'/'above'

      await tester.tap(_backspaceKey());
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);
    });

    testWidgets('a rapid double-tap cannot append a disabled letter', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);

      // Two taps on 'a' with no frame between them: the second races the
      // rebuild that disables the key. No word starts with 'aa', so the model
      // must drop the racing tap rather than produce 'aa'.
      await tester.tap(keyboardKey('a'), warnIfMissed: false);
      await tester.tap(keyboardKey('a'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(fieldText(tester, 0), equals('a'));
    });

    testWidgets('key letters are hidden from the accessibility tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);

      // A malicious accessibility service must not be able to read the letters:
      // the keys are wrapped in ExcludeSemantics.
      expect(find.bySemanticsLabel('a'), findsNothing);
      expect(find.bySemanticsLabel('e'), findsNothing);
      handle.dispose();
    });

    testWidgets('word fields are hidden from the accessibility tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'zone');

      // Excluding the keys is not enough: a TextField publishes its text as
      // its semantics value, so the whole word grid is excluded too — the
      // typed word must not be readable back from the field.
      expect(
        find.ancestor(
          of: wordField(0),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('zone'), findsNothing);
      handle.dispose();
    });

    testWidgets('suggestions are hidden from the accessibility tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'zo');

      // The chips are visible on screen…
      expect(find.text('zone'), findsOneWidget);
      expect(find.text('zoo'), findsOneWidget);
      // …but an accessibility service must not read the candidate words.
      expect(find.bySemanticsLabel('zone'), findsNothing);
      expect(find.bySemanticsLabel('zoo'), findsNothing);
      handle.dispose();
    });

    testWidgets('the passphrase field stays out of the IME suggestion caches', (
      tester,
    ) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});

      // The passphrase is key material too: the OS keyboard may serve it, but
      // its autocorrect and prediction caches must never see the value.
      final field = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Optional Passphrase',
        ),
      );
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
    });
  });

  group('MnemonicWidget paranoid mode', () {
    testWidgets('suggestions stay visible in paranoid mode', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'zo');
      expect(find.text('zone'), findsOneWidget);
      expect(find.text('zoo'), findsOneWidget);

      await tester.tap(shuffleToggle());
      await tester.pumpAndSettle();

      // Still offered — paranoid mode randomises their order, it does not
      // remove them.
      expect(find.text('zone'), findsOneWidget);
      expect(find.text('zoo'), findsOneWidget);
    });

    testWidgets('a word can still be typed with a shuffled layout', (
      tester,
    ) async {
      Mnemonic? submitted;
      await pumpWidget(tester, onSubmit: (m) => submitted = m);

      await focusField(tester, 0);
      await tester.tap(shuffleToggle());
      await tester.pumpAndSettle();

      // Keys are found by their letter, not their position, so a shuffled
      // layout does not change what can be typed.
      await fillAll(tester, validWords);
      await submit(tester);

      expect(submitted, isNotNull);
      expect(submitted!.words, equals(validWords));
    });

    testWidgets('the layout reshuffles after each key tap', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);
      await tester.tap(shuffleToggle());
      await tester.pumpAndSettle();

      final before = keyPositions(tester);
      await tapKey(tester, 'a'); // a valid first letter, so enabled
      final after = keyPositions(tester);

      // A full reshuffle: the odds of an identical 26-letter arrangement are
      // vanishing, so the positions must differ.
      expect(mapEquals(before, after), isFalse);
    });

    testWidgets('basic mode keeps a stable layout across taps', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);

      final before = keyPositions(tester);
      await tapKey(tester, 'a');
      final after = keyPositions(tester);

      // No shuffle in basic mode: every key still shown sits where it was.
      for (final letter in after.keys) {
        if (before.containsKey(letter)) {
          expect(after[letter], equals(before[letter]), reason: letter);
        }
      }
    });
  });

  group('MnemonicWidget suggestions', () {
    testWidgets('suggests the words matching the focused prefix', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'zo');

      // 'zone' and 'zoo' are the only english words starting with 'zo'.
      expect(find.text('zone'), findsOneWidget);
      expect(find.text('zoo'), findsOneWidget);
    });

    testWidgets('tapping a suggestion fills the focused field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'zo');
      await tester.tap(find.text('zone'));
      await tester.pump();

      expect(fieldText(tester, 0), equals('zone'));
    });

    testWidgets('offers only checksum valid words on the last field', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      final valid = bip39.Mnemonic.lastWordCandidates(
        words: validWords.take(11).toList(),
      );
      expect(valid, hasLength(128));

      await typeWord(tester, 11, 'sen');

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

      await focusField(tester, 11);

      expect(find.text('128 possible last words'), findsOneWidget);
    });

    testWidgets('tapping a chip on the last field dismisses the keyboard', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, [...validWords.take(11), '']);

      await typeWord(tester, 11, 'sen');
      await tester.tap(find.text('senior'));
      await tester.pump();

      expect(fieldText(tester, 11), equals('senior'));
      expect(fieldHasFocus(tester, 11), isFalse);
    });

    testWidgets('does not auto fill the last field from the candidates', (
      tester,
    ) async {
      // A transcription error that is itself a valid word: shell -> sell.
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
      await typeWord(tester, 11, 'se');

      // the field keeps what the user typed
      expect(fieldText(tester, 11), equals('se'));

      await submit(tester);
      expect(submitted, isNull);
    });

    testWidgets('still completes the real last word, then fails the checksum', (
      tester,
    ) async {
      final typed = [...validWords.take(11)];
      typed[3] = 'sell';

      var submitted = false;
      await pumpWidget(
        tester,
        onSubmit: (_) => submitted = true,
        allowAutoFillWords: true,
      );
      await fillAll(tester, [...typed, '']);
      await typeWord(tester, 11, 'seni');

      expect(fieldText(tester, 11), equals('senior'));

      await submit(tester);
      expect(submitted, isFalse);
      expect(
        fieldText(tester, 11),
        isEmpty,
        reason: 'an invalid checksum clears the last word',
      );
    });

    testWidgets('auto fills once the prefix leaves a single candidate', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      // 'aba' can only be 'abandon'.
      await typeWord(tester, 0, 'aba');

      expect(fieldText(tester, 0), equals('abandon'));
      // The completion was the only possibility left: focus stays put.
      expect(fieldHasFocus(tester, 0), isTrue);

      // Every letter key is now disabled: a completed unique word cannot be
      // extended, so a stray tap cannot break it.
      await tester.tap(keyboardKey('a'), warnIfMissed: false);
      await tester.pump();
      expect(fieldText(tester, 0), equals('abandon'));
    });

    testWidgets('the clear icon empties an auto-filled field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await typeWord(tester, 0, 'aba');
      expect(fieldText(tester, 0), equals('abandon'));

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);

      // Editable again right away, focus never left: 'abi' -> 'ability'.
      await tapKey(tester, 'a');
      await tapKey(tester, 'b');
      await tapKey(tester, 'i');
      expect(fieldText(tester, 0), equals('ability'));
      expect(fieldHasFocus(tester, 0), isTrue);
    });

    testWidgets('backspace clears the whole word, not one character', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {}, allowAutoFillWords: true);

      await typeWord(tester, 0, 'aba');
      expect(fieldText(tester, 0), equals('abandon'));

      // A word is entered as a unit and deleted as a unit: one backspace wipes
      // the field rather than trimming to 'abando'.
      await tester.tap(_backspaceKey());
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);
    });

    testWidgets('marks a last word that cannot close the checksum as wrong', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      // Reference colours from the first field: a non-word prefix (invalid),
      // then a valid wordlist word.
      await typeWord(tester, 0, 'aban');
      final invalidColor = badgeColor(tester, 0);
      await clearField(tester, 0);
      await typeWord(tester, 0, validWords.first);
      final validColor = badgeColor(tester, 0);

      // Complete the first eleven words so the last field has a candidate pool.
      for (var i = 1; i < 11; i++) {
        await typeWord(tester, i, validWords[i]);
      }

      // 'zoo' is a wordlist word but not a checksum candidate here: wrong word.
      await typeWord(tester, 11, 'zoo');
      expect(badgeColor(tester, 11), equals(invalidColor));

      await clearField(tester, 11);
      await typeWord(tester, 11, 'senior');
      expect(badgeColor(tester, 11), equals(validColor));
    });
  });
}
