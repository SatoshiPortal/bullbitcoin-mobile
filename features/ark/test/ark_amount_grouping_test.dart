import 'package:bull_ark/generated/l10n/ark_localizations.dart';
import 'package:bull_ark/src/ui/ark_amount.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Builder, FocusManager, TextField, TextEditingValue, TextSelection;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, config;

void main() {
  for (final language in ['en', 'fr']) {
    final grouped = language == 'en' ? '30,000' : '30 000';
    final edited = language == 'en' ? '309,000' : '309 000';
    testWidgets(
      'Board $language grouping never changes raw edits or the one handoff',
      (tester) async {
        final amounts = <Sats>[];
        await tester.pumpWidget(
          app(
            ArkBoardAmountScreen(
              config: config(),
              onReviewRequest: (_, amount) => amounts.add(amount),
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        BullInputText input() =>
            tester.widget<BullInputText>(find.byType(BullInputText));
        await tester.enterText(field, '30000');
        await tester.pumpAndSettle();
        expect(input().value, '30000');
        expect(amounts, isEmpty);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(input().value, grouped);
        expect(tester.widget<TextField>(field).controller?.text, grouped);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(input().value, '30000');
        expect(tester.widget<TextField>(field).controller?.text, '30000');
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '309000',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pumpAndSettle();
        expect(input().value, '309000');
        expect(
          tester.widget<TextField>(field).controller?.selection.baseOffset,
          3,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(input().value, edited);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(input().value, '309000');
        expect(amounts, isEmpty);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final loc = ArkLocalizations.of(
          tester.element(find.byType(ArkBoardAmountScreen)),
        );
        if (loc == null) throw StateError('Missing Ark localization');
        final action = find.widgetWithText(BullButton, loc.boardAction);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(amounts.map((amount) => amount.value), [BigInt.from(309000)]);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'observed $language integer grouping is exact beyond double precision',
      (tester) async {
        final amount = Sats(BigInt.parse('9007199254740993'));
        final number = language == 'en'
            ? '9,007,199,254,740,993'
            : '9 007 199 254 740 993';
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => Column(
                children: [
                  BullText(
                    formatArkObservedSats(context, amount, withUnit: false),
                  ),
                  BullText(formatArkSats(context, amount)),
                ],
              ),
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(number), findsOneWidget);
        expect(find.text('$number sats'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  final preferences = <String, BullAmountSnapshot?>{
    'missing': null,
    'unready': const BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: false,
      isReady: false,
    ),
    'hidden': const BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: true,
      isReady: true,
    ),
    'visible': const BullAmountSnapshot(
      unit: BitcoinUnit.sats,
      hideAmounts: false,
      isReady: true,
    ),
  };
  for (final entry in preferences.entries) {
    for (final amount in <Sats?>[null, Sats.fromInt(1234)]) {
      testWidgets(
        'number-only privacy wins before unknown ${entry.key}/${amount == null}',
        (tester) async {
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => BullText(
                  formatArkObservedSats(context, amount, withUnit: false),
                ),
              ),
              amountPreferences: entry.value,
            ),
          );
          await tester.pumpAndSettle();
          final expected = entry.key == 'visible'
              ? (amount == null ? 'Unavailable' : '1,234')
              : '••••';
          expect(find.text(expected), findsOneWidget);
          expect(find.text('1234'), findsNothing);
        },
      );
    }
  }
}
