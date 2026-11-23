import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:scanning/scanning.dart';

void main() {
  testWidgets('French inputs use standalone Material localizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: TextField()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(TextField));
    expect(MaterialLocalizations.of(context).copyButtonLabel, 'Copier');
  });

  test('onboarding UI catalogues support every app locale', () {
    expect(
      ScanningLocalizations.supportedLocales,
      unorderedEquals(AppLocalizations.supportedLocales),
    );
    expect(
      MnemonicEntryLocalizations.supportedLocales,
      unorderedEquals(AppLocalizations.supportedLocales),
    );
  });

  testWidgets(
    'onboarding UI uses the app locale and keeps missing-text fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final scanning = ScanningLocalizations.of(context);
      final mnemonic = MnemonicEntryLocalizations.of(context);
      expect(scanning.scanningProgressLabel('42'), 'Analyse : 42 %');
      expect(mnemonic.mnemonicWordCountLabel, 'Mots');
      expect(
        mnemonic.mnemonicShuffleKeyboardHint,
        'Scramble the keys and suggestions on every tap',
      );
    },
  );
}
