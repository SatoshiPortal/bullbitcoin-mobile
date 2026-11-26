import 'dart:async';

import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_done_page.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPaymentStepRail, bullUiLocalizationsDelegate;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import '../buy_fixtures.dart';

BuyDone _done(int polls) {
  final base = buyDoneState as BuyDone;
  return BuyDone(
    base.open,
    base.request,
    WatchWatching(buyOrder(status: OrderStatus.inProgress), polls, 0, 1),
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required BuyDone done,
    required Future<bool> Function() animations,
    required List<String> opened,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      localizationsDelegates: const [
        ...ExchangeLocalizations.localizationsDelegates,
        bullUiLocalizationsDelegate,
      ],
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: BuyDonePage(
        done: done,
        unit: BitcoinUnit.sats,
        now: () => buyBeforeDeadline,
        onClose: () {},
        openOrder: opened.add,
        onAccelerate: (_) {},
        showPaymentAnimations: animations,
      ),
    ),
  );

  testWidgets('preference off: hands off once to the details, no rail', (
    tester,
  ) async {
    final opened = <String>[];
    await pump(
      tester,
      done: _done(1),
      animations: () async => false,
      opened: opened,
    );
    await tester.pump();
    expect(opened, [buyOrder().orderId]);
    expect(find.byType(BullPaymentStepRail), findsNothing);

    // Repeated payout-watch updates never navigate again.
    for (var polls = 2; polls < 5; polls++) {
      await pump(
        tester,
        done: _done(polls),
        animations: () async => false,
        opened: opened,
      );
      await tester.pump();
    }
    expect(opened, hasLength(1));
  });

  testWidgets('preference on: shows the rail and does not hand off', (
    tester,
  ) async {
    final opened = <String>[];
    await pump(
      tester,
      done: _done(1),
      animations: () async => true,
      opened: opened,
    );
    await tester.pump();
    expect(find.byType(BullPaymentStepRail), findsOneWidget);
    expect(opened, isEmpty);

    await tester.tap(find.text('View details'));
    expect(opened, [buyOrder().orderId]);
  });

  testWidgets('waits for the preference before choosing a path', (
    tester,
  ) async {
    final opened = <String>[];
    final gate = Completer<bool>();
    await pump(
      tester,
      done: _done(1),
      animations: () => gate.future,
      opened: opened,
    );
    await tester.pump();
    expect(find.byType(BullPaymentStepRail), findsNothing);
    expect(opened, isEmpty);

    gate.complete(false);
    await tester.pump();
    expect(opened, hasLength(1));
    expect(find.byType(BullPaymentStepRail), findsNothing);
  });
}
