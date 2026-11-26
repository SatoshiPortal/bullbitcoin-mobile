// Keep Send tests independent of the application namespace.
import 'package:send/src/payment/ui/screens/send_payment_page.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget page({
    bool ready = false,
    VoidCallback? onContinue,
    Widget amount = const Text('Amount editor'),
  }) => MaterialApp(
    theme: ThemeData(
      extensions: testBullExtensions,
      textTheme: testBullTypography.toTextTheme(),
    ),
    localizationsDelegates: bullUiLocalizationsDelegates,
    supportedLocales: BullUiLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => SendPaymentPage(
        title: 'Send',
        stepLabels: const ['Recipient', 'Amount', 'Confirm'],
        stepSemanticLabel: (index, label) => 'Step ${index + 1}: $label',
        recipientLabel: 'To',
        recipient: const Text('Recipient editor'),
        amountLabel: 'Amount',
        amount: amount,
        balance: const Text('Balance 1,250,000 sats'),
        fromLabel: 'From',
        wallet: const Text('Wallet picker'),
        maxLabel: 'MAX',
        settingsLabel: 'Advanced settings',
        feeSummary: 'Fast',
        continueLabel: 'Continue',
        onBack: () {},
        onSettings: () {},
        onMax: () {},
        onContinue: onContinue,
        recipientReady: ready,
      ),
    ),
  );

  testWidgets('recipient gates amount and Continue on one page', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(page());
    expect(find.text('Amount'), findsOneWidget, reason: 'only the step bar');
    expect(find.text('From'), findsNothing);
    expect(find.text('Amount editor'), findsNothing);
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
    expect(continued, isFalse);
    await tester.pumpWidget(
      page(ready: true, onContinue: () => continued = true),
    );
    expect(find.text('Recipient editor'), findsOneWidget);
    expect(find.text('Amount editor'), findsOneWidget);
    final maxAction = find.ancestor(
      of: find.text('MAX'),
      matching: find.byType(BullFieldAction),
    );
    expect(
      tester.getBottomRight(maxAction).dx,
      tester.view.physicalSize.width / tester.view.devicePixelRatio - 24,
    );
    expect(
      tester.getTopLeft(find.text('From')).dy,
      greaterThan(tester.getBottomLeft(find.text('Recipient editor')).dy),
    );
    expect(
      tester.getBottomLeft(find.text('Wallet picker')).dy,
      lessThan(tester.getTopLeft(find.text('Amount').last).dy),
    );
    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
  });

  testWidgets('keyboard hides settings while Continue remains above it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(ready: true, onContinue: () {}));
    expect(find.text('Advanced settings'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.text('Advanced settings'), findsNothing);
    expect(tester.getBottomLeft(find.text('Continue')).dy, lessThan(544));
    expect(
      tester.getBottomLeft(find.text('Balance 1,250,000 sats')).dy,
      lessThan(tester.getTopLeft(find.text('Continue')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside the amount closes the keyboard', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      page(ready: true, amount: TextField(focusNode: focus)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.text('From'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
