import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_renew_sheet.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Center;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Builder;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show Rig;

final price = BitcoinPrice(
  currency: SupportedCurrency.cad,
  fiatAmount: 100000,
  fetchedAt: DateTime.utc(2026, 11, 17),
);

Future<Future<ArkRenewOutcome?>> open(
  WidgetTester tester,
  ArkOperationCubit cubit,
) async {
  late Future<ArkRenewOutcome?> outcome;
  await tester.pumpWidget(
    app(
      Builder(
        builder: (context) => Center(
          child: BullButton.primary(
            label: 'Open',
            onPressed: () => outcome = ArkRenewSheet.show(
              context,
              cubit: cubit,
              price: price,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return outcome;
}

BullButton sheetButton(WidgetTester tester, String label) =>
    tester.widget<BullButton>(
      find.descendant(
        of: find.byType(ArkRenewSheet),
        matching: find.widgetWithText(BullButton, label),
      ),
    );

void main() {
  testWidgets('the sheet shows the amount, renew fee and amount after fee', (
    tester,
  ) async {
    final r = Rig();
    await r.ready(amount: 100000);
    await open(tester, r.cubit);
    expect(find.text('Renew VTXO?'), findsOneWidget);
    expect(
      find.text('This renews the VTXO in the next Ark round.'),
      findsOneWidget,
    );
    expect(find.text('100,000 sats'), findsOneWidget);
    expect(find.text('(100.00 CAD)'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('100 sats (0.10 CAD)'), findsOneWidget);
    expect(find.text('99,900 sats (99.90 CAD)'), findsOneWidget);
    expect(sheetButton(tester, 'Renew').disabled, false);
  });

  testWidgets('Cancel closes the sheet without renewing', (tester) async {
    final r = Rig();
    await r.ready();
    final outcome = await open(tester, r.cubit);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ArkRenewSheet), findsNothing);
    expect(await outcome, isNull);
    expect(r.client.calls.where((c) => c == 'submit'), isEmpty);
  });

  testWidgets('a started renewal closes the sheet with its outcome', (
    tester,
  ) async {
    final r = Rig();
    await r.ready();
    r.client.submitted = Ok(
      ArkOperation(
        id: 'attempt-1',
        kind: ArkOperationKind.renewal,
        status: ArkOperationStatus.succeeded,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    );
    final outcome = await open(tester, r.cubit);
    sheetButton(tester, 'Renew').onPressed();
    await tester.pumpAndSettle();
    expect(find.byType(ArkRenewSheet), findsNothing);
    expect(await outcome, ArkRenewOutcome.started);
  });

  testWidgets('a failed quote offers Retry and never Renew', (tester) async {
    final r = Rig();
    await r.cubit.load(); // The client refuses quotes by default.
    await open(tester, r.cubit);
    expect(find.text('Renew fee'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ArkRenewSheet),
        matching: find.widgetWithText(BullButton, 'Renew'),
      ),
      findsNothing,
    );
    expect(sheetButton(tester, 'Retry').disabled, false);
  });
}
