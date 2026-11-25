import 'package:bull_ui/testing.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:mnemonic_entry/testing.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullLabeledTextInput,
        BullMnemonicKeyboard,
        BullSegmented,
        BullTypography;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
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
  bool allowLabel = false,
  String? externalError,
  required void Function(Mnemonic) onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The passphrase field renders BullInputText, which reads the BullTheme
      // extension off the ambient ThemeData and throws without it.
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: const [
        MnemonicEntryLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: MnemonicEntryLocalizations.supportedLocales,
      home: Scaffold(
        // MnemonicWidget owns its own scroll and docks the keyboard, so it is
        // given bounded height (the test surface) rather than an outer scroll.
        body: MnemonicWidget(
          initialLength: length,
          onSubmit: onSubmit,
          allowAutoFillWords: allowAutoFillWords,
          allowMultipleMnemonicLength: allowMultipleMnemonicLength,
          allowLabel: allowLabel,
          allowPassphrase: allowPassphrase,
          externalError: externalError,
        ),
      ),
    ),
  );
}

Finder wordField(int index) => find.byType(TextField).at(index);

/// A [TextField] that uses Material's string placeholder.
TextField fieldByHint(WidgetTester tester, String hint) =>
    tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      ),
    );

const secretPassphrase = 'correct horse';

Finder passphraseField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'Optional Passphrase',
);

/// Every label, value, hint and tooltip published in the semantics tree.
List<String> semanticsStrings(WidgetTester tester) {
  final strings = <String>[];
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    strings.addAll([data.label, data.value, data.hint, data.tooltip]);
    node.visitChildren(visit);
    return true;
  }

  final owner = tester.getSemantics(find.byType(Scaffold)).owner;
  final root = owner?.rootSemanticsNode;
  if (root != null) visit(root);
  return strings;
}

/// A key on the in-app keyboard, scoped so the letter is matched on the
/// keyboard and not in a field or a suggestion chip.
Finder keyboardKey(String letter) => find.descendant(
  of: find.byType(BullMnemonicKeyboard),
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
  of: find.byType(BullMnemonicKeyboard),
  matching: find.byIcon(Icons.backspace_outlined),
);

Finder shuffleToggle() => find.byKey(const Key('mnemonicParanoidToggle'));

Finder enterKey() => find.byKey(const Key('mnemonicEnterKey'));

/// Taps enter, tolerating a disabled key so a test can assert it did nothing.
Future<void> tapEnter(WidgetTester tester) async {
  await tester.tap(enterKey(), warnIfMissed: false);
  await tester.pumpAndSettle();
}

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

/// The color of the index badge of field [index] - the widget that answers "is this word acceptable". The badge is the nearest decorated box around its label inside that field, whatever its size.
Color? badgeColor(WidgetTester tester, int index) {
  final displayIndex = index + 1;
  final label = displayIndex < 10 ? '0$displayIndex' : '$displayIndex';
  final badge = tester.widget<Container>(
    find
        .ancestor(
          of: find.descendant(
            of: find.byType(MnemonicWord).at(index),
            matching: find.text(label),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first,
  );
  final decoration = badge.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
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
      expect(find.byType(BullMnemonicKeyboard), findsNothing);

      await focusField(tester, 0);
      expect(find.byType(BullMnemonicKeyboard), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(BullMnemonicKeyboard), findsNothing);
    });

    testWidgets('tapping empty page space dismisses the keyboard', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);
      expect(find.byType(BullMnemonicKeyboard), findsOneWidget);

      // Tap the gap between the two columns, level with the first field — a
      // point that lands on no field.
      final row = tester.getRect(wordField(0));
      await tester.tapAt(Offset(400, row.center.dy));
      await tester.pumpAndSettle();

      expect(find.byType(BullMnemonicKeyboard), findsNothing);
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

    testWidgets('a refused long phrase scrolls its error into view', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 760);
      addTearDown(tester.view.reset);
      await pumpWidget(
        tester,
        length: bip39.MnemonicLength.words24,
        onSubmit: (_) {},
      );

      await submit(tester);
      await tester.pumpAndSettle();

      // The submit button is pinned under the scroll: the error at the end of
      // the 24 fields must be brought on screen, not left below the fold.
      final error = tester.getRect(
        find.text('Enter all words of your mnemonic'),
      );
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(error.top, greaterThanOrEqualTo(viewport.top));
      expect(error.bottom, lessThanOrEqualTo(viewport.bottom));
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

      await tester.tap(find.text('24'));
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
        final picker = tester.widget<BullSegmented>(
          find.byKey(const Key('mnemonicLengthPicker')),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        node23.requestFocus();
        picker.onSelected('12');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNWidgets(12));
      },
    );
  });

  group('MnemonicWidget page', () {
    testWidgets('the word count is a segmented control of every length', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      final picker = tester.widget<BullSegmented>(
        find.byKey(const Key('mnemonicLengthPicker')),
      );
      expect(picker.items, {'12', '15', '18', '21', '24'});
      expect(picker.initialValue, '12');
      expect(find.byType(DropdownButton<bip39.MnemonicLength>), findsNothing);
    });

    testWidgets('a single allowed length shows no word count control', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        allowMultipleMnemonicLength: false,
        onSubmit: (_) {},
      );
      expect(find.byKey(const Key('mnemonicLengthPicker')), findsNothing);
    });

    testWidgets('the word count title reads in the caption role', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      final title = tester.widget<Text>(
        find
            .descendant(
              of: find.ancestor(
                of: find.byKey(const Key('mnemonicLengthPicker')),
                matching: find.byType(Column),
              ),
              matching: find.byType(Text),
            )
            .first,
      );
      final caption = BullTypography.standard.caption;
      expect(title.style?.fontSize, caption.fontSize);
      expect(title.style?.height, caption.height);
    });

    testWidgets('word fields are compact and read at body size', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      final first = tester.getRect(find.byType(MnemonicWord).at(0));
      final second = tester.getRect(find.byType(MnemonicWord).at(1));
      final right = tester.getRect(find.byType(MnemonicWord).at(6));
      expect(first.height, 40);
      expect(second.top - first.bottom, 8);
      expect(right.left - first.right, 16);
      final word = find.descendant(
        of: find.byType(MnemonicWord).first,
        matching: find.byType(TextField),
      );
      final body = BullTypography.standard.body;
      final wordStyle = tester.widget<TextField>(word).style;
      final badgeStyle = tester.widget<Text>(find.text('01')).style;
      expect(wordStyle?.fontSize, body.fontSize);
      expect(wordStyle?.height, body.height);
      expect(badgeStyle?.fontSize, body.fontSize);
      expect(badgeStyle?.height, body.height);
      expect(badgeStyle?.fontWeight, FontWeight.w700);
    });

    testWidgets('a typed word keeps the field at its resting height', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      final resting = tester.getRect(find.byType(MnemonicWord).first).height;
      await typeWord(tester, 0, 'ab');
      // The clear button appears: it must not push the field taller than its
      // neighbour in the other column.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.getRect(find.byType(MnemonicWord).first).height, resting);
    });

    testWidgets('word fields grow with the system text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpWidget(tester, onSubmit: (_) {});
      final field = tester.getRect(find.byType(MnemonicWord).first);
      final badge = tester.getRect(find.text('01'));
      final text = tester.getRect(
        find.descendant(
          of: find.byType(MnemonicWord).first,
          matching: find.byType(EditableText),
        ),
      );
      expect(field.height, greaterThan(40));
      for (final inner in [badge, text]) {
        expect(inner.top, greaterThanOrEqualTo(field.top));
        expect(inner.bottom, lessThanOrEqualTo(field.bottom));
      }
    });

    testWidgets('submit is pinned at the bottom, hidden while typing', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      final button = find.byType(BullButton);
      expect(button, findsOneWidget);
      // Pinned: under the scroll area, not inside it.
      expect(
        find.ancestor(of: button, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      expect(
        tester.getRect(button).bottom,
        greaterThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio - 40,
        ),
      );

      await focusField(tester, 0);
      expect(button, findsNothing);
      expect(find.byType(BullMnemonicKeyboard), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);
    });

    testWidgets('the passphrase row says what the switch does', (tester) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      expect(find.text('Optional extra word (BIP39)'), findsOneWidget);
      await tester.ensureVisible(find.text('Optional extra word (BIP39)'));
      // The subtitle is part of the tappable row.
      await tester.tap(find.text('Optional extra word (BIP39)'));
      await tester.pumpAndSettle();
      expect(find.text('Entered below, never shown'), findsOneWidget);
      expect(passphraseField(), findsOneWidget);
    });
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

    testWidgets('passphrase entry is initially collapsed', (tester) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      expect(passphraseField(), findsNothing);
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      expect(passphraseField(), findsOneWidget);
      await tester.enterText(passphraseField(), '  Mixed Case ');
      await tester.pump();
      expect(
        find.text('Leading or trailing spaces are part of your passphrase.'),
        findsOneWidget,
      );
    });

    testWidgets('turning the passphrase off hides it and drops its text', (
      tester,
    ) async {
      Mnemonic? submitted;
      await pumpWidget(
        tester,
        allowPassphrase: true,
        onSubmit: (m) => submitted = m,
      );
      await fillAll(tester, validWords);
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      await tester.enterText(passphraseField(), 'secret');
      await tester.pump();

      await tester.tap(find.byKey(const Key('mnemonicPassphraseSwitch')));
      await tester.pumpAndSettle();
      expect(passphraseField(), findsNothing);

      await submit(tester);
      expect(submitted?.passphrase, '');

      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(passphraseField()).controller?.text, '');
    });

    testWidgets('clears the typed passphrase when the app pauses', (
      tester,
    ) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      await tester.enterText(passphraseField(), 'secret');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester.widget<TextField>(passphraseField()).controller?.text,
        isEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets(
      'a cleared passphrase blocks submission until explicitly skipped',
      (tester) async {
        Mnemonic? submitted;
        await pumpWidget(
          tester,
          allowPassphrase: true,
          onSubmit: (m) => submitted = m,
        );
        await fillAll(tester, validWords);
        await tester.ensureVisible(find.text('I have a passphrase'));
        await tester.tap(find.text('I have a passphrase'));
        await tester.pumpAndSettle();
        await tester.enterText(passphraseField(), 'secret');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await submit(tester);
        expect(submitted, isNull);
        expect(
          find.text(
            'For your privacy, your passphrase was cleared. Enter it again or choose to continue without one.',
          ),
          findsOneWidget,
        );
        await tester.enterText(passphraseField(), 'x');
        await tester.enterText(passphraseField(), '');
        await submit(tester);
        expect(submitted, isNull);
        await tester.ensureVisible(find.text('Continue without a passphrase'));
        await tester.tap(find.text('Continue without a passphrase'));
        await tester.pumpAndSettle();
        await submit(tester);
        expect(submitted?.passphrase, '');
      },
    );

    testWidgets('re-entering a cleared passphrase permits submission', (
      tester,
    ) async {
      Mnemonic? submitted;
      await pumpWidget(
        tester,
        allowPassphrase: true,
        onSubmit: (m) => submitted = m,
      );
      await fillAll(tester, validWords);
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      await tester.enterText(passphraseField(), 'secret');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.enterText(passphraseField(), ' Mixed ');
      await submit(tester);
      expect(submitted?.passphrase, ' Mixed ');
    });

    testWidgets('the passphrase field takes the value exactly as typed', (
      tester,
    ) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();

      final field = fieldByHint(tester, 'Optional Passphrase');

      // The passphrase feeds seed derivation character by character, so iOS
      // must not reformat it into a different wallet.
      expect(field.smartQuotesType, SmartQuotesType.disabled);
      expect(field.smartDashesType, SmartDashesType.disabled);

      // It is key material too: the OS keyboard may serve it, but its
      // autocorrect and prediction caches must never see the value.
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.keyboardType, TextInputType.visiblePassword);
    });

    testWidgets('the passphrase is obscured until revealed', (tester) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();

      expect(fieldByHint(tester, 'Optional Passphrase').obscureText, isTrue);

      await tester.ensureVisible(find.byTooltip('Show passphrase'));
      await tester.tap(find.byTooltip('Show passphrase'));
      await tester.pump();

      expect(fieldByHint(tester, 'Optional Passphrase').obscureText, isFalse);
    });

    testWidgets('the passphrase never reaches the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      await tester.enterText(passphraseField(), secretPassphrase);
      await tester.pump();

      // Screen readers and accessibility services read the semantics tree: a
      // field publishing its text there hands the passphrase to them.
      expect(semanticsStrings(tester), isNot(contains(contains('horse'))));
      // The field stays reachable by its name.
      expect(find.bySemanticsLabel('Passphrase'), findsWidgets);
      handle.dispose();
    });

    testWidgets('the passphrase cannot be selected or copied', (tester) async {
      await pumpWidget(tester, allowPassphrase: true, onSubmit: (_) {});
      await tester.ensureVisible(find.text('I have a passphrase'));
      await tester.tap(find.text('I have a passphrase'));
      await tester.pumpAndSettle();
      await tester.enterText(passphraseField(), secretPassphrase);
      await tester.ensureVisible(passphraseField());
      await tester.pumpAndSettle();

      await tester.longPress(passphraseField());
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing);
      expect(find.text('Select all'), findsNothing);
    });

    testWidgets('a non-secret labelled input keeps the platform defaults', (
      tester,
    ) async {
      await pumpWidget(tester, allowLabel: true, onSubmit: (_) {});

      // The hardening is opt-in: ordinary text still types normally.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(BullLabeledTextInput),
          matching: find.byType(TextField),
        ),
      );
      expect(field.smartQuotesType, SmartQuotesType.enabled);
      expect(field.smartDashesType, SmartDashesType.enabled);
      expect(field.enableSuggestions, isTrue);
      expect(field.autocorrect, isTrue);
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

    testWidgets('the shortest words lead, nothing before the first letter', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 0);
      BullMnemonicKeyboard keyboard() => tester.widget<BullMnemonicKeyboard>(
        find.byType(BullMnemonicKeyboard),
      );
      expect(keyboard().suggestions, isEmpty);

      await typeWord(tester, 0, 'ab');
      // 'able' is the shortest word after 'ab', then 'about' and 'above'.
      expect(keyboard().suggestions, ['able', 'about', 'above']);
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

    testWidgets('enter moves to the next word once the word is whole', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await typeWord(tester, 0, 'raise');

      await tapEnter(tester);

      expect(fieldHasFocus(tester, 1), isTrue);
      expect(fieldText(tester, 0), equals('raise'));
    });

    testWidgets('enter skips an untouched field', (tester) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await focusField(tester, 1);

      await tapEnter(tester);
      expect(fieldHasFocus(tester, 2), isTrue);

      // Repeatable, so a run of empty fields can be stepped through.
      await tapEnter(tester);
      expect(fieldHasFocus(tester, 3), isTrue);
      expect(fieldText(tester, 1), isEmpty);
      expect(fieldText(tester, 2), isEmpty);
    });

    testWidgets('enter holds the field while the word is a prefix', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      // 'rai' still matches raise/rail/rain: nothing has been decided yet.
      await typeWord(tester, 0, 'rai');

      await tapEnter(tester);

      expect(fieldHasFocus(tester, 0), isTrue);
      expect(
        fieldText(tester, 0),
        equals('rai'),
        reason: 'enter must never pick a word on the user behalf',
      );
      expect(fieldText(tester, 1), isEmpty);
    });

    testWidgets('enter on the last field dismisses the keyboard', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});
      await fillAll(tester, validWords);

      await focusField(tester, 11);
      await tapEnter(tester);

      expect(fieldHasFocus(tester, 11), isFalse);
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

      // Complete the first eleven words so the last field has a candidate pool.
      for (var i = 0; i < 11; i++) {
        await typeWord(tester, i, validWords[i]);
      }

      // 'zoo' is a wordlist word but not a checksum candidate here: wrong word,
      // shown once the field is left.
      await typeWord(tester, 11, 'zoo');
      await focusField(tester, 0);
      expect(badgeColor(tester, 11), testBullTheme.error);

      await clearField(tester, 11);
      await typeWord(tester, 11, 'senior');
      expect(badgeColor(tester, 11), testBullTheme.success);
    });

    testWidgets('a half-typed word stays neutral until the field is left', (
      tester,
    ) async {
      await pumpWidget(tester, onSubmit: (_) {});

      await typeWord(tester, 0, 'ab');
      expect(badgeColor(tester, 0), testBullTheme.onSurface);

      await focusField(tester, 1);
      expect(badgeColor(tester, 0), testBullTheme.error);

      await typeWord(tester, 1, validWords[1]);
      expect(badgeColor(tester, 1), testBullTheme.success);
    });
  });
}
