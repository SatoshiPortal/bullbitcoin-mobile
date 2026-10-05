import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/transaction_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    bool isLoading = false,
    bool isIncoming = true,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: TransactionDetailsPage(
          title: 'Transaction',
          isLoading: isLoading,
          isIncoming: isIncoming,
          onClose: onClose ?? () {},
          status: const Text('Confirmed'),
          amount: const Text('12 345 sats'),
          details: const Text('Transaction details'),
        ),
      ),
    );
  }

  testWidgets('renders shared transaction details content', (tester) async {
    await pumpPage(tester);

    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('12 345 sats'), findsOneWidget);
    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.byIcon(Icons.south_east), findsOneWidget);
  });

  testWidgets('uses outgoing direction badge', (tester) async {
    await pumpPage(tester, isIncoming: false);

    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });

  testWidgets('calls close callback', (tester) async {
    var closed = false;
    await pumpPage(tester, onClose: () => closed = true);

    await tester.tap(find.byIcon(Icons.close));

    expect(closed, isTrue);
  });

  testWidgets('shows loading placeholders', (tester) async {
    await pumpPage(tester, isLoading: true);

    expect(find.text('Confirmed'), findsNothing);
    expect(find.text('12 345 sats'), findsNothing);
    expect(find.text('Transaction details'), findsNothing);
  });
}
