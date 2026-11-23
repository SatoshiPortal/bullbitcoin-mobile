import 'package:wallet_import/src/ui/mnemonic_widget.dart' show MnemonicWord;

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/testing.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:mnemonic_entry/testing.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullMnemonicKeyboard, BullSecretTextInput, BullSegmented;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

Future<void> host(
  WidgetTester tester, {
  required void Function(Mnemonic) onSubmit,
  bip39.Language language = bip39.Language.english,
  bool allowPassphrase = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    localizationsDelegates: const [
      MnemonicEntryLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: MnemonicEntryLocalizations.supportedLocales,
    home: Scaffold(
      body: MnemonicWidget(
        initialLength: bip39.MnemonicLength.words12,
        language: language,
        allowAutoFillWords: false,
        allowLabel: false,
        allowPassphrase: allowPassphrase,
        submitLabel: 'Submit',
        onSubmit: onSubmit,
      ),
    ),
  ),
);

Future<void> fill(WidgetTester tester, List<String> words) async {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  for (var i = 0; i < words.length; i++) {
    fields[i].controller?.text = words[i];
  }
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Submit'));
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();
}

// Shared public fixture already used by secrets/vault_language_test.dart.
const ambiguous = [
  'crucial',
  'million',
  'voyage',
  'sentence',
  'mobile',
  'suspect',
  'double',
  'minute',
  'virus',
  'noble',
  'junior',
  'wagon',
];

MnemonicEntryLocalizations loc(WidgetTester tester) =>
    MnemonicEntryLocalizations.of(tester.element(find.byType(MnemonicWidget)));

String fieldText(WidgetTester tester, int index) =>
    tester
        .widgetList<TextField>(find.byType(TextField))
        .elementAt(index)
        .controller
        ?.text ??
    '';

/// The wordlists in the order the language key lists them.
const entryLanguages = [
  bip39.Language.english,
  bip39.Language.spanish,
  bip39.Language.french,
  bip39.Language.italian,
  bip39.Language.czech,
  bip39.Language.portuguese,
  bip39.Language.japanese,
  bip39.Language.korean,
  bip39.Language.simplifiedChinese,
  bip39.Language.traditionalChinese,
];

Finder languageKey() => find.byKey(const Key('mnemonicLanguageKey'));

/// Chooses [language] on the keyboard's language key, from the field being
/// typed ([field], the first by default).
Future<void> pick(
  WidgetTester tester,
  bip39.Language language, {
  int field = 0,
}) async {
  await focusField(tester, field);
  await tester.tap(languageKey());
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(
      ValueKey('mnemonicLanguageOption${entryLanguages.indexOf(language)}'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> focusField(WidgetTester tester, int index) async {
  final field = find.byType(TextField).at(index);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> focusFirstField(WidgetTester tester) => focusField(tester, 0);

BullMnemonicKeyboard keyboard(WidgetTester tester) =>
    tester.widget<BullMnemonicKeyboard>(find.byType(BullMnemonicKeyboard));

/// The letter rows as typed, NFC for readability.
List<String> rows(WidgetTester tester) {
  final widget = keyboard(tester);
  var start = 0;
  return [
    for (final count in widget.rows)
      nfc(widget.layout.sublist(start, start += count).join()),
  ];
}

Set<String> disabledLetters(WidgetTester tester) {
  final widget = keyboard(tester);
  return {
    for (final key in widget.layout)
      if (!widget.enabledLetters.contains(key)) key,
  };
}

Finder key(String label) => find.descendant(
  of: find.byType(BullMnemonicKeyboard),
  matching: find.text(label),
);

void main() {
  late Directory logDirectory;
  setUp(() async {
    logDirectory = await Directory.systemTemp.createTemp('language-log-');
    log = Logger.replace(directory: logDirectory);
  });
  tearDown(() async {
    await log.flush();
    await logDirectory.delete(recursive: true);
  });
  testWidgets('the language key offers every BIP39 wordlist', (tester) async {
    await host(tester, onSubmit: (_) {});
    // The page header no longer carries a language picker.
    expect(find.byType(DropdownButton<bip39.Language>), findsNothing);
    await focusFirstField(tester);
    expect(keyboard(tester).languages, hasLength(bip39.Language.values.length));
    expect(entryLanguages.toSet(), bip39.Language.values.toSet());
    await pick(tester, bip39.Language.japanese);
    expect(
      find.descendant(of: languageKey(), matching: find.text('JA')),
      findsOneWidget,
    );
    expect(keyboard(tester).selectedLanguage, 6);
  });

  testWidgets(
    'stale keyboard callbacks cannot write after language or focus changes',
    (tester) async {
      await host(tester, onSubmit: (_) {});
      await focusFirstField(tester);
      final oldKeyboard = tester.widget<BullMnemonicKeyboard>(
        find.byType(BullMnemonicKeyboard),
      );
      await pick(tester, bip39.Language.french);
      await focusFirstField(tester);
      oldKeyboard.onLetter('a');
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);

      final currentKeyboard = tester.widget<BullMnemonicKeyboard>(
        find.byType(BullMnemonicKeyboard),
      );
      final second = find.byType(TextField).at(1);
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      currentKeyboard.onLetter('a');
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);
      expect(fieldText(tester, 1), isEmpty);
    },
  );

  testWidgets('shared Chinese phrase requires a renewed explicit choice', (
    tester,
  ) async {
    Mnemonic? submitted;
    await host(tester, onSubmit: (value) => submitted = value);
    final words = bip39.Mnemonic(
      List.filled(16, 0),
      bip39.Language.simplifiedChinese,
    ).words;
    await fill(tester, words);
    await submit(tester);
    expect(submitted, isNull);
    await pick(tester, bip39.Language.traditionalChinese);
    await submit(tester);
    expect(submitted?.language, bip39.Language.traditionalChinese);
    submitted = null;
    await fill(tester, [words.first]);
    await fill(tester, words);
    // A text edit must invalidate the previous choice.
    final first = tester
        .widgetList<TextField>(find.byType(TextField))
        .first
        .controller;
    if (first == null) fail('first mnemonic field has no controller');
    first.text = '';
    first.text = words.first;
    await tester.pumpAndSettle();
    await submit(tester);
    expect(submitted, isNull);
  });

  testWidgets('non-Latin import preserves a Unicode passphrase', (
    tester,
  ) async {
    Mnemonic? submitted;
    await host(
      tester,
      allowPassphrase: true,
      onSubmit: (value) => submitted = value,
    );
    final words = bip39.Mnemonic(
      List.filled(16, 0),
      bip39.Language.japanese,
    ).words;
    await fill(tester, words);
    await pick(tester, bip39.Language.japanese);
    const passphrase = 'Cafe\u0301 日本語';
    await tester.ensureVisible(find.text('I have a passphrase'));
    await tester.tap(find.text('I have a passphrase'));
    await tester.pumpAndSettle();
    tester
        .widget<BullSecretTextInput>(find.byType(BullSecretTextInput))
        .onChanged(passphrase);
    await submit(tester);
    expect(submitted?.language, bip39.Language.japanese);
    expect(submitted?.passphrase, passphrase);
  });

  testWidgets('stale suggestion cannot write after the prefix changes', (
    tester,
  ) async {
    await host(tester, onSubmit: (_) {});
    await focusFirstField(tester);
    keyboard(tester).onLetter('a');
    await tester.pumpAndSettle();
    // 'act' is the shortest word after 'a': the best suggestion.
    final firstHint = find
        .ancestor(of: find.text('act').last, matching: find.byType(InkWell))
        .first;
    final oldTap = tester.widget<InkWell>(firstHint).onTap;
    if (oldTap == null) fail('suggestion has no tap callback');
    keyboard(tester).onLetter('b');
    await tester.pumpAndSettle();
    oldTap();
    await tester.pump();
    expect(fieldText(tester, 0), 'ab');
  });

  for (final (language, word) in [
    (bip39.Language.japanese, 'あおぞら'),
    (bip39.Language.korean, '가격'),
    (bip39.Language.simplifiedChinese, '的'),
  ]) {
    testWidgets('${language.name} types through protected character keys', (
      tester,
    ) async {
      await host(tester, language: language, onSubmit: (_) {});
      final field = find.byType(TextField).first;
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      for (final character in nfkd(word).split('')) {
        final key = find.descendant(
          of: find.byType(BullMnemonicKeyboard),
          matching: find.text(BullMnemonicKeyboard.keyLabel(character)),
        );
        await tester.scrollUntilVisible(
          key,
          120,
          scrollable: find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          ),
          maxScrolls: 200,
        );
        await tester.tap(key);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<TextField>(field).controller?.text, nfkd(word));
      expect(tester.testTextInput.isVisible, isFalse);
    });
  }

  testWidgets(
    'changing languages refreshes the last-word checksum candidates',
    (tester) async {
      await host(tester, language: bip39.Language.english, onSubmit: (_) {});
      await fill(tester, List.filled(12, 'abandon'));
      final nodes = tester
          .widgetList<MnemonicWord>(find.byType(MnemonicWord))
          .toList();
      final englishCandidates = nodes.last.candidates?.value;
      expect(englishCandidates, isNotNull);
      // 'abandon' is in both lists, so the words stay.
      await pick(tester, bip39.Language.french);
      final frenchCandidates = tester
          .widgetList<MnemonicWord>(find.byType(MnemonicWord))
          .last
          .candidates
          ?.value;
      expect(frenchCandidates, isNot(equals(englishCandidates)));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'abandon',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ambiguous English French sentence requires an explicit choice', (
    tester,
  ) async {
    Mnemonic? submitted;
    await host(tester, onSubmit: (value) => submitted = value);
    await fill(tester, ambiguous);
    await submit(tester);
    expect(submitted, isNull);
    // The ambiguity notice offers both readings; choosing one keeps the words.
    final french = find.widgetWithText(
      BullButton,
      loc(tester).mnemonicLanguageName('french'),
    );
    await tester.ensureVisible(french);
    await tester.tap(french);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 0), ambiguous.first);
    await submit(tester);
    expect(submitted?.language, bip39.Language.french);
    expect(submitted?.words, ambiguous);
    final rows = await tester.runAsync(() async => log.readLogs());
    expect(rows?.map((row) => row.split('\t')[2]), [
      'Mnemonic submit refused reason=language_required',
      'Mnemonic language selected language=french',
    ]);
  });

  testWidgets(
    'detection suggests Spanish without changing the selected language',
    (tester) async {
      Mnemonic? submitted;
      await host(tester, onSubmit: (value) => submitted = value);
      final words = bip39.Mnemonic(
        List.filled(16, 0),
        bip39.Language.spanish,
      ).words;
      await fill(tester, words);
      // Find by the localization itself rather than assuming its English wording.
      final context = tester.element(find.byType(MnemonicWidget));
      final loc = MnemonicEntryLocalizations.of(context);
      final action = find.text(
        loc.mnemonicLanguageSuggestion(loc.mnemonicLanguageName('spanish')),
      );
      expect(action, findsOneWidget);
      await submit(tester);
      expect(submitted, isNull);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(submitted?.language, bip39.Language.spanish);
      // Detection never rewrites the words.
      expect(fieldText(tester, 0), words.first);
    },
  );

  for (final language in [
    bip39.Language.english,
    bip39.Language.spanish,
    bip39.Language.french,
    bip39.Language.italian,
    bip39.Language.czech,
    bip39.Language.portuguese,
    bip39.Language.japanese,
    bip39.Language.korean,
    bip39.Language.simplifiedChinese,
    bip39.Language.traditionalChinese,
  ]) {
    testWidgets('${language.name} imports after explicit picker selection', (
      tester,
    ) async {
      Mnemonic? submitted;
      await host(tester, onSubmit: (value) => submitted = value);
      final words = bip39.Mnemonic(List.filled(16, 0), language).words;
      await fill(tester, words.map(nfc).toList());
      // After the words: a choice answers one phrase.
      await pick(tester, language);
      await submit(tester);
      expect(submitted?.language, language);
      expect(submitted?.words.map(nfkd), words.map(nfkd));
    });
  }

  for (final language in [
    bip39.Language.japanese,
    bip39.Language.korean,
    bip39.Language.spanish,
  ]) {
    testWidgets('${language.name} accepts composed public vector words', (
      tester,
    ) async {
      Mnemonic? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [
            MnemonicEntryLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: MnemonicEntryLocalizations.supportedLocales,
          home: Scaffold(
            body: MnemonicWidget(
              language: language,
              initialLength: bip39.MnemonicLength.words12,
              allowAutoFillWords: false,
              allowLabel: false,
              allowPassphrase: false,
              submitLabel: 'Submit',
              onSubmit: (value) => submitted = value,
            ),
          ),
        ),
      );
      // Published BIP39 zero-entropy vector; controllers are the input seam,
      // since production fields deliberately refuse OS keyboard input.
      final words = bip39.Mnemonic(List.filled(16, 0), language).words;
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      for (var i = 0; i < words.length; i++) {
        fields[i].controller?.text =
            '${language.separator}${nfc(words[i])}${language.separator}';
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(submitted?.language, language);
      expect(submitted?.words.map(nfkd), words.map(nfkd));
    });
  }

  group('a checksum-valid reading decides the language', () {});

  group('a language choice answers one phrase', () {
    testWidgets('a single shared word does not announce an ambiguity', (
      tester,
    ) async {
      await host(tester, onSubmit: (_) {});
      await fill(tester, ['abandon']);
      expect(find.text(loc(tester).mnemonicLanguageAmbiguous), findsNothing);
      await fill(tester, ambiguous);
      expect(find.text(loc(tester).mnemonicLanguageAmbiguous), findsOneWidget);
    });

    testWidgets('editing a word asks for the language again', (tester) async {
      Mnemonic? submitted;
      await host(tester, onSubmit: (value) => submitted = value);
      await fill(tester, ambiguous);
      await pick(tester, bip39.Language.french);
      await fill(tester, ['abandon']);
      await fill(tester, ambiguous);
      await submit(tester);
      expect(submitted, isNull);
      expect(find.text(loc(tester).mnemonicLanguageAmbiguous), findsOneWidget);
      // French is already current: the key changes nothing, the notice's
      // reading answers the new phrase.
      final french = find.widgetWithText(
        BullButton,
        loc(tester).mnemonicLanguageName('french'),
      );
      await tester.ensureVisible(french);
      await tester.tap(french);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(submitted?.language, bip39.Language.french);
      expect(submitted?.words, ambiguous);
    });

    testWidgets('changing the length asks for the language again', (
      tester,
    ) async {
      Mnemonic? submitted;
      await host(tester, onSubmit: (value) => submitted = value);
      await fill(tester, ambiguous);
      await pick(tester, bip39.Language.french);
      final lengths = find.byKey(const Key('mnemonicLengthPicker'));
      tester.widget<BullSegmented>(lengths).onSelected('15');
      await tester.pumpAndSettle();
      tester.widget<BullSegmented>(lengths).onSelected('12');
      await tester.pumpAndSettle();
      await fill(tester, ambiguous);
      await submit(tester);
      expect(submitted, isNull);
      expect(find.text(loc(tester).mnemonicLanguageAmbiguous), findsOneWidget);
    });
  });

  for (final language in [
    bip39.Language.simplifiedChinese,
    bip39.Language.traditionalChinese,
  ]) {
    testWidgets('${language.name} keys follow the wordlist order', (
      tester,
    ) async {
      await host(tester, language: language, onSubmit: (_) {});
      await focusFirstField(tester);
      final layout = tester
          .widget<BullMnemonicKeyboard>(find.byType(BullMnemonicKeyboard))
          .layout;
      expect(layout, hasLength(2048));
      expect(layout, language.list.map(nfkd).toList());
    });
  }

  group('keys show a legible label', () {
    testWidgets(
      'a Japanese voicing mark key shows a base but inserts the mark',
      (tester) async {
        await host(tester, language: bip39.Language.japanese, onSubmit: (_) {});
        await focusFirstField(tester);
        await fill(tester, [nfkd('あおそ')]);
        expect(key('\u25CC\u3099'), findsOneWidget);
        expect(key('\u3099'), findsNothing);
        await tester.tap(key('\u25CC\u3099'));
        await tester.pumpAndSettle();
        expect(fieldText(tester, 0), nfkd('あおぞ'));
      },
    );

    testWidgets('a Korean leading consonant key shows a standalone jamo', (
      tester,
    ) async {
      await host(tester, language: bip39.Language.korean, onSubmit: (_) {});
      await focusFirstField(tester);
      expect(key('\u3131'), findsOneWidget);
      expect(key('\u1100'), findsNothing);
      await tester.tap(key('\u3131'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 0), '\u1100');
    });
  });

  group('the language key', () {
    testWidgets('words of another wordlist are cleared, typing restarts', (
      tester,
    ) async {
      await host(tester, onSubmit: (_) {});
      await fill(tester, ['zoo', 'abandon']);
      await pick(tester, bip39.Language.french, field: 1);
      for (var i = 0; i < 12; i++) {
        expect(fieldText(tester, i), isEmpty, reason: 'field $i');
      }
      final first = tester.widget<TextField>(find.byType(TextField).first);
      expect(first.focusNode?.hasFocus, isTrue);
      expect(keyboard(tester).selectedLanguage, 2);
    });

    testWidgets('words valid in the new wordlist are kept', (tester) async {
      await host(tester, onSubmit: (_) {});
      // Both are English and French words.
      await fill(tester, ['abandon', 'million']);
      await pick(tester, bip39.Language.french);
      expect(fieldText(tester, 0), 'abandon');
      expect(fieldText(tester, 1), 'million');
      expect(keyboard(tester).selectedLanguage, 2);
    });

    testWidgets('a prefix being typed in the new wordlist is kept', (
      tester,
    ) async {
      await host(tester, onSubmit: (_) {});
      await focusFirstField(tester);
      // 'aba' starts 'abaisser' in French.
      for (final letter in 'aba'.split('')) {
        keyboard(tester).onLetter(letter);
        await tester.pump();
      }
      await pick(tester, bip39.Language.french);
      expect(fieldText(tester, 0), 'aba');
    });

    testWidgets('an empty phrase just switches the layout', (tester) async {
      await host(tester, onSubmit: (_) {});
      await pick(tester, bip39.Language.french);
      expect(rows(tester), ['azertyuiop', 'qsdfghjklm', 'wxcvbn']);
    });

    testWidgets('choosing the current wordlist changes nothing', (
      tester,
    ) async {
      await host(tester, onSubmit: (_) {});
      await fill(tester, ['zoo']);
      await pick(tester, bip39.Language.english);
      expect(fieldText(tester, 0), 'zoo');
      expect(keyboard(tester).selectedLanguage, 0);
    });
  });

  group('letter layouts', () {
    for (final (language, expected, disabled) in [
      (bip39.Language.english, ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'], {'x'}),
      (
        bip39.Language.french,
        ['azertyuiop', 'qsdfghjklm', 'wxcvbn'],
        <String>{},
      ),
      (
        bip39.Language.spanish,
        ['qwertyuiop', 'asdfghjklñ', 'zxcvbnm'],
        // No Spanish word starts with ñ either.
        {'w', 'x', nfkd('\u00f1')},
      ),
      (
        bip39.Language.italian,
        ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'],
        {'h', 'j', 'k', 'w', 'x', 'y'},
      ),
      (
        bip39.Language.portuguese,
        ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'],
        {'k', 'w', 'y'},
      ),
      (
        bip39.Language.czech,
        ['qwertzuiop', 'asdfghjkl', 'yxcvbnm'],
        {'q', 'w', 'y'},
      ),
    ]) {
      testWidgets('${language.name} opens on its national layout', (
        tester,
      ) async {
        await host(tester, language: language, onSubmit: (_) {});
        await focusFirstField(tester);
        expect(rows(tester), expected);
        expect(disabledLetters(tester), disabled);
        // Only French and Spanish have letters off the layout.
        expect(keyboard(tester).accents.map(nfc).toList(), switch (language) {
          bip39.Language.french => ['é', 'è'],
          bip39.Language.spanish => ['á', 'é', 'í', 'ó', 'ú'],
          _ => isEmpty,
        });
      });
    }

    testWidgets('Spanish types an accent from the second page in NFKD', (
      tester,
    ) async {
      await host(tester, language: bip39.Language.spanish, onSubmit: (_) {});
      await focusFirstField(tester);
      await tester.tap(find.byKey(const Key('mnemonicPageKey')));
      await tester.pump();
      await tester.tap(key(nfkd('á')));
      await tester.pumpAndSettle();
      for (final letter in 'baco'.split('')) {
        await tester.tap(key(letter));
        await tester.pumpAndSettle();
      }
      expect(fieldText(tester, 0), nfkd('ábaco'));
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a long press on e offers only the accents that lead on', (
      tester,
    ) async {
      await host(tester, language: bip39.Language.french, onSubmit: (_) {});
      await focusFirstField(tester);
      // French words start with é, never with è.
      expect(keyboard(tester).variants['e'], [nfkd('é')]);
      await tester.longPress(key('e'));
      await tester.pumpAndSettle();
      await tester.tap(key(nfkd('é')));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 0), nfkd('é'));
      // After 'él' (élève, élégant), both accents lead on.
      await tester.tap(key('l'));
      await tester.pumpAndSettle();
      expect(keyboard(tester).variants['e']?.toSet(), {
        nfkd('\u00e9'),
        nfkd('\u00e8'),
      });
    });

    testWidgets('the scrambled French layout keeps each key once', (
      tester,
    ) async {
      await host(tester, language: bip39.Language.french, onSubmit: (_) {});
      await focusFirstField(tester);
      final natural = keyboard(tester).layout;
      await tester.tap(find.byKey(const Key('mnemonicParanoidToggle')));
      await tester.pump();
      for (var tap = 0; tap < 3; tap++) {
        final shuffled = keyboard(tester).layout;
        expect(shuffled, hasLength(natural.length));
        expect(shuffled.toSet(), natural.toSet());
        expect(shuffled, isNot(natural));
        await tester.tap(key('a'));
        await tester.pump();
      }
    });

    testWidgets('a grid keeps each possible character once when scrambled', (
      tester,
    ) async {
      await host(tester, language: bip39.Language.korean, onSubmit: (_) {});
      await focusFirstField(tester);
      final natural = keyboard(tester).layout;
      expect(natural, hasLength(18));
      await tester.tap(find.byKey(const Key('mnemonicParanoidToggle')));
      await tester.pump();
      final shuffled = keyboard(tester).layout;
      expect(shuffled.toSet(), natural.toSet());
      expect(shuffled, hasLength(natural.length));
    });

    testWidgets('Chinese shows no suggestion', (tester) async {
      await host(
        tester,
        language: bip39.Language.simplifiedChinese,
        onSubmit: (_) {},
      );
      await focusFirstField(tester);
      keyboard(tester).onLetter(bip39.Language.simplifiedChinese.list.first);
      await tester.pumpAndSettle();
      expect(keyboard(tester).suggestions, isEmpty);
    });
  });
}
