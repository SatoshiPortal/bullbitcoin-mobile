import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/novlang/novlang_app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novlang/novlang.dart';

Future<void> _pump(
  WidgetTester tester,
  String label,
  NovlangPolicy policy,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: [
        NovlangAppLocalizationsDelegate(policy),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: LabelText(label)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('auto-swap label display', () {
    for (final label in [
      LabelSystem.autoSwap.label,
      // Written by published versions before the system label was used.
      LabelSystem.legacyAutoTransferLabel,
    ]) {
      testWidgets('"$label" shows Auto Swap without a store constraint', (
        tester,
      ) async {
        await _pump(tester, label, NovlangPolicy.none);
        expect(find.text('Auto Swap'), findsOneWidget);
      });

      testWidgets('"$label" shows Auto Transfer under the Apple policy', (
        tester,
      ) async {
        await _pump(tester, label, NovlangPolicy.apple);
        expect(find.text('Auto Transfer'), findsOneWidget);
      });
    }

    testWidgets('other labels are shown as written', (tester) async {
      await _pump(tester, 'auto-transfer', NovlangPolicy.none);
      expect(find.text('auto-transfer'), findsOneWidget);
    });

    test(
      'the legacy literal is displayed as the system label, not stored as one',
      () {
        expect(
          LabelSystem.displayedAs(LabelSystem.legacyAutoTransferLabel),
          LabelSystem.autoSwap,
        );
        expect(
          LabelSystem.isSystemLabel(LabelSystem.legacyAutoTransferLabel),
          isFalse,
        );
      },
    );
  });
}
