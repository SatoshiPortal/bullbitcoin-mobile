import 'dart:io';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/widgets/mnemonic_keyboard.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullSecretTextInput;
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart';

Future<void> host(
  WidgetTester tester, {
  required void Function(Mnemonic) onSubmit,
  bip39.Language language = bip39.Language.english,
  bool englishOnly = false,
  bool allowPassphrase = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MnemonicWidget(
        initialLength: bip39.MnemonicLength.words12,
        language: language,
        englishOnly: englishOnly,
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

// The shared vector with its last word swapped: valid only in French.
final frenchOnly = [...ambiguous.take(11), 'amateur'];

AppLocalizations loc(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MnemonicWidget)));

String fieldText(WidgetTester tester, int index) =>
    tester
        .widgetList<TextField>(find.byType(TextField))
        .elementAt(index)
        .controller
        ?.text ??
    '';

Future<void> pick(WidgetTester tester, bip39.Language language) async {
  tester
      .widget<DropdownButton<bip39.Language>>(
        find.byKey(const Key('mnemonicLanguagePicker')),
      )
      .onChanged
      ?.call(language);
  await tester.pumpAndSettle();
}

Future<void> focusFirstField(WidgetTester tester) async {
  final field = find.byType(TextField).first;
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Finder key(String label) => find.descendant(
  of: find.byType(MnemonicKeyboard),
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
  testWidgets('import picker offers every BIP39 wordlist', (tester) async {
    await host(tester, onSubmit: (_) {});
    final picker = tester.widget<DropdownButton<bip39.Language>>(
      find.byKey(const Key('mnemonicLanguagePicker')),
    );
    expect(
      picker.items?.map((item) => item.value).toSet(),
      bip39.Language.values.toSet(),
    );
    await pick(tester, bip39.Language.japanese);
    expect(
      tester
          .widget<DropdownButton<bip39.Language>>(
            find.byKey(const Key('mnemonicLanguagePicker')),
          )
          .value,
      bip39.Language.japanese,
    );
  });

  testWidgets(
    'stale keyboard callbacks cannot write after language or focus changes',
    (tester) async {
      await host(tester, onSubmit: (_) {});
      await focusFirstField(tester);
      final oldKeyboard = tester.widget<MnemonicKeyboard>(
        find.byType(MnemonicKeyboard),
      );
      await pick(tester, bip39.Language.french);
      await focusFirstField(tester);
      oldKeyboard.onLetter('a');
      await tester.pump();
      expect(fieldText(tester, 0), isEmpty);

      final currentKeyboard = tester.widget<MnemonicKeyboard>(
        find.byType(MnemonicKeyboard),
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
        .controller!;
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
    final firstHint = find
        .ancestor(of: find.text('abandon').last, matching: find.byType(InkWell))
        .first;
    final oldTap = tester.widget<InkWell>(firstHint).onTap!;
    final keyboard = tester.widget<MnemonicKeyboard>(
      find.byType(MnemonicKeyboard),
    );
    keyboard.onLetter('b');
    await tester.pumpAndSettle();
    oldTap();
    await tester.pump();
    expect(fieldText(tester, 0), 'b');
  });

  for (final (language, word) in [
    (bip39.Language.japanese, 'あおぞら'),
    (bip39.Language.korean, '가격'),
    (bip39.Language.spanish, 'ábaco'),
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
          of: find.byType(MnemonicKeyboard),
          matching: find.text(MnemonicKeyboard.keyLabel(character)),
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
      tester
          .widget<DropdownButton<bip39.Language>>(
            find.byKey(const Key('mnemonicLanguagePicker')),
          )
          .onChanged
          ?.call(bip39.Language.french);
      await tester.pumpAndSettle();
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
    expect(
      find.byKey(const Key('mnemonicLanguagePicker')).hitTestable(),
      findsOneWidget,
    );
    final picker = tester.widget<DropdownButton<bip39.Language>>(
      find.byKey(const Key('mnemonicLanguagePicker')),
    );
    picker.onChanged?.call(bip39.Language.french);
    await tester.pumpAndSettle();
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
      final loc = AppLocalizations.of(context);
      final action = find.text(
        loc.mnemonicLanguageSuggestion(loc.mnemonicLanguageName('spanish')),
      );
      expect(action, findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<bip39.Language>>(
              find.byKey(const Key('mnemonicLanguagePicker')),
            )
            .value,
        bip39.Language.english,
      );
      await submit(tester);
      expect(submitted, isNull);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(submitted?.language, bip39.Language.spanish);
    },
  );

  testWidgets(
    'default recovery explains non-English refusal before submission',
    (tester) async {
      Mnemonic? submitted;
      await host(
        tester,
        englishOnly: true,
        onSubmit: (value) => submitted = value,
      );
      await fill(
        tester,
        bip39.Mnemonic(List.filled(16, 0), bip39.Language.japanese).words,
      );
      await submit(tester);
      expect(submitted, isNull);
      expect(find.byKey(const Key('mnemonicLanguagePicker')), findsNothing);
      expect(
        find.textContaining('Default wallets currently require an English'),
        findsOneWidget,
      );
      expect(find.textContaining('Something went wrong'), findsNothing);
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
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  group('a checksum-valid reading decides the language', () {
    testWidgets(
      'default recovery explains a phrase valid only in French and keeps it',
      (tester) async {
        Mnemonic? submitted;
        await host(
          tester,
          englishOnly: true,
          onSubmit: (value) => submitted = value,
        );
        await fill(tester, frenchOnly);
        await submit(tester);
        expect(submitted, isNull);
        expect(fieldText(tester, 11), 'amateur');
        final l = loc(tester);
        expect(find.text(l.mnemonicDefaultEnglishOnly), findsOneWidget);
        expect(find.text(l.mnemonicInvalidChecksumError), findsNothing);
      },
    );

    testWidgets('default recovery keeps an English and French phrase English', (
      tester,
    ) async {
      Mnemonic? submitted;
      await host(
        tester,
        englishOnly: true,
        onSubmit: (value) => submitted = value,
      );
      await fill(tester, ambiguous);
      await submit(tester);
      expect(submitted?.language, bip39.Language.english);
      expect(submitted?.words, ambiguous);
      final rows = await tester.runAsync(() async => log.readLogs());
      expect(rows, isEmpty);
    });

    testWidgets(
      'French words with a bad checksum under English name both wordlists',
      (tester) async {
        Mnemonic? submitted;
        await host(tester, onSubmit: (value) => submitted = value);
        await fill(tester, List.filled(12, 'abaisser'));
        await submit(tester);
        expect(submitted, isNull);
        final l = loc(tester);
        expect(
          find.text(
            l.mnemonicOtherLanguageWordsError(
              l.mnemonicLanguageName('french'),
              l.mnemonicLanguageName('english'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l.mnemonicUnknownWordError), findsNothing);
        expect(fieldText(tester, 11), 'abaisser');
      },
    );
  });

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
      await pick(tester, bip39.Language.french);
      await submit(tester);
      expect(submitted?.language, bip39.Language.french);
    });

    testWidgets('changing the length asks for the language again', (
      tester,
    ) async {
      Mnemonic? submitted;
      await host(tester, onSubmit: (value) => submitted = value);
      await fill(tester, ambiguous);
      await pick(tester, bip39.Language.french);
      final lengths = find.byType(MnemonicLengthDropdown);
      tester
          .widget<MnemonicLengthDropdown>(lengths)
          .onChanged(bip39.MnemonicLength.words15);
      await tester.pumpAndSettle();
      tester
          .widget<MnemonicLengthDropdown>(lengths)
          .onChanged(bip39.MnemonicLength.words12);
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
          .widget<MnemonicKeyboard>(find.byType(MnemonicKeyboard))
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
}
