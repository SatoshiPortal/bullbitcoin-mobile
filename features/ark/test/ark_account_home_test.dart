import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullDetailsTable, BullDetailsTableItem;
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as wallet;
import 'ark_operations_test.dart' show account;
import 'ark_information_widget_test.dart' show app;

ArkSnapshot snapshot({Sats? pending, Sats? reserve}) => ArkSnapshot(
  account: account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 16),
  stale: false,
  spendable: Sats.fromInt(1234),
  pending: pending,
  confirmedReserve: reserve,
  recovery: ArkRecoveryStatus.complete,
  renewal: ArkRenewalStatus.current,
);

Future<void> mount(WidgetTester tester, ArkSnapshot observed) async {
  final client = wallet.Client()..snapshot = Ok(observed);
  await tester.pumpWidget(
    app(wallet.screen(wallet.controller(client), <String>[])),
  );
  await tester.pump();
}

void main() {
  testWidgets('home keeps one named settings action and no button stack', (
    tester,
  ) async {
    await mount(tester, snapshot(pending: Sats.zero, reserve: Sats.zero));
    expect(find.byTooltip('Ark actions'), findsOneWidget);
    for (final label in ['Refresh', 'Board to Ark', 'VTXOs', 'Ark info']) {
      expect(find.widgetWithText(BullButton, label), findsNothing);
    }
    await wallet.openActions(tester);
    for (final label in [
      'Refresh',
      'Board to Ark',
      'VTXOs',
      'Emergency exit',
      'Ark info',
    ]) {
      expect(find.widgetWithText(BullButton, label), findsOneWidget);
    }
  });

  testWidgets('empty observed activity shows the illustrated state', (
    tester,
  ) async {
    await mount(tester, snapshot(pending: Sats.zero, reserve: Sats.zero));
    expect(find.byKey(const ValueKey('ark-empty-activity')), findsOneWidget);
    expect(find.text('Observed activity'), findsNothing);
  });

  testWidgets('zero pending and reserve are not repeated on home', (
    tester,
  ) async {
    await mount(tester, snapshot(pending: Sats.zero, reserve: Sats.zero));
    expect(wallet.amounts(tester), isEmpty);
  });

  testWidgets('non-zero or unknown pending and reserve stay visible', (
    tester,
  ) async {
    await mount(tester, snapshot(pending: Sats.fromInt(7), reserve: null));
    final items = tester
        .widgetList<BullDetailsTable>(find.byType(BullDetailsTable))
        .expand((t) => t.items.whereType<BullDetailsTableItem>());
    expect(items.map((i) => i.label), [
      'Pending (sats)',
      'On-chain fee reserve (sats)',
    ]);
  });
}
