import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_ui/testing.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_address_viewer.dart';

void main() {
  testWidgets('a deposit address that measures itself lays out on the review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => QuoteReviewPage(
            title: 'Sell',
            rows: const [('You pay', '10 EUR')],
            deadline: DateTime.now().add(const Duration(minutes: 5)),
            refreshLabel: 'Price refreshes in ',
            details: [fakeAddressViewer(context, 'tb1qdeposit')],
            status: const QuoteLive(),
            onConfirm: () {},
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('tb1qdeposit'), findsOneWidget);
  });
}
