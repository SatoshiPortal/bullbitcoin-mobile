import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullTransactionDetailsPage;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    bool isLoading = false,
    bool isIncoming = true,
    VoidCallback? onClose,
    Future<void> Function()? onRefresh,
    Widget? errorContent,
    bool canPopBack = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: BullTransactionDetailsPage(
          title: 'Transaction',
          isLoading: isLoading,
          isIncoming: isIncoming,
          onClose: onClose ?? () {},
          onRefresh: onRefresh,
          errorContent: errorContent,
          canPopBack: canPopBack,
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

  testWidgets('keeps refresh available on an error screen', (tester) async {
    var refreshes = 0;
    await pumpPage(
      tester,
      errorContent: const Text('Could not load transaction'),
      onRefresh: () async {
        refreshes++;
      },
    );
    expect(find.text('Could not load transaction'), findsOneWidget);
    expect(find.text('Transaction details'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 420));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('runs close on a refused root back action', (tester) async {
    var closes = 0;
    await pumpPage(tester, canPopBack: false, onClose: () => closes++);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(closes, 1);
    expect(find.byType(BullTransactionDetailsPage), findsOneWidget);
  });
}
