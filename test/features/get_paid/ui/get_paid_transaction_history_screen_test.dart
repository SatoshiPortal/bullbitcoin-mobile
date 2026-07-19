import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_state.dart';
import 'package:bb_mobile/features/get_paid/public/get_paid_routes.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_detail_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_history_screen.dart';
import 'package:bb_mobile/features/invoices/public/invoices_routes.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _StubHistoryCubit extends Cubit<GetPaidTransactionHistoryState>
    implements GetPaidTransactionHistoryCubit {
  int loadCalls = 0;
  int refreshCalls = 0;
  int loadMoreCalls = 0;

  _StubHistoryCubit(super.initialState);

  @override
  Future<void> load() async => loadCalls++;

  @override
  Future<void> refresh() async => refreshCalls++;

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}

GetPaidTransaction _transaction({
  GetPaidTransactionSource source = GetPaidTransactionSource.lightningAddress,
  String? comment,
}) {
  return GetPaidTransaction(
    transactionId: '10000000-0000-4000-8000-000000000001',
    source: source,
    invoiceId: source == GetPaidTransactionSource.lightningAddress
        ? null
        : '50000000-0000-4000-8000-000000000005',
    amountSat: 2100,
    receivedAt: DateTime.utc(2026, 7, 18, 12),
    rail: GetPaidTransactionRail.lightning,
    settlementState: GetPaidSettlementState.settled,
    late: false,
    comment: comment,
  );
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

Future<_StubHistoryCubit> _pumpHistory(
  WidgetTester tester,
  GetPaidTransactionHistoryState state,
) async {
  final cubit = _StubHistoryCubit(state);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    _app(
      BlocProvider<GetPaidTransactionHistoryCubit>.value(
        value: cubit,
        child: const GetPaidTransactionHistoryScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('renders first-load skeleton, empty, and retry states', (
    tester,
  ) async {
    await _pumpHistory(
      tester,
      const GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.loading,
      ),
    );
    expect(find.byType(BullShimmerLine), findsWidgets);

    await _pumpHistory(
      tester,
      const GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.loaded,
      ),
    );
    expect(find.text('No payments yet'), findsOneWidget);

    final failureCubit = await _pumpHistory(
      tester,
      const GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.failure,
        failure: GetPaidFailure.unavailable(),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(failureCubit.refreshCalls, 1);
  });

  testWidgets('list shows payment facts but keeps comment private to detail', (
    tester,
  ) async {
    final cubit = await _pumpHistory(
      tester,
      GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.loaded,
        transactions: [_transaction(comment: 'private payer note')],
        nextCursor: 'next',
      ),
    );

    expect(find.text('2,100 sats'), findsOneWidget);
    expect(find.text('Lightning Address'), findsOneWidget);
    expect(find.textContaining('Lightning'), findsWidgets);
    expect(find.textContaining('Settled'), findsWidgets);
    expect(find.text('private payer note'), findsNothing);
    await tester.tap(find.text('Load more'));
    expect(cubit.loadMoreCalls, 1);
  });

  testWidgets('row opens detail, where comment and invoice link are explicit', (
    tester,
  ) async {
    final transaction = _transaction(
      source: GetPaidTransactionSource.invoice,
      comment: 'private payer note',
    );
    final cubit = _StubHistoryCubit(
      GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.loaded,
        transactions: [transaction],
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              BlocProvider<GetPaidTransactionHistoryCubit>.value(
                value: cubit,
                child: const GetPaidTransactionHistoryScreen(),
              ),
          routes: [
            GoRoute(
              name: GetPaidDashboardRoute.getPaidTransactionDetail.name,
              path: 'detail',
              builder: (context, state) => GetPaidTransactionDetailScreen(
                transaction: state.extra! as GetPaidTransaction,
              ),
            ),
          ],
        ),
        GoRoute(
          name: InvoicesRoute.detail.name,
          path: '/invoices/:id',
          builder: (context, state) =>
              Scaffold(body: Text('invoice-${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    expect(find.text('private payer note'), findsNothing);
    await tester.tap(
      find.byKey(ValueKey('get-paid-transaction-${transaction.stableKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('private payer note'), findsOneWidget);
    expect(find.text(transaction.transactionId), findsNothing);
    expect(find.text(transaction.invoiceId!), findsNothing);
    await tester.tap(find.text('View invoice'));
    await tester.pumpAndSettle();
    expect(find.text('invoice-${transaction.invoiceId}'), findsOneWidget);
  });
}
