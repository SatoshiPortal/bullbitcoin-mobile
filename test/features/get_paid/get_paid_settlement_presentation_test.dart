import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_settlement.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_state.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_detail_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_history_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubHistoryCubit extends Cubit<GetPaidTransactionHistoryState>
    implements GetPaidTransactionHistoryCubit {
  _StubHistoryCubit(super.initialState);

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

GetPaidTransaction _tx({GetPaidSettlement? settlement}) => GetPaidTransaction(
  transactionId: '10000000-0000-4000-8000-000000000001',
  source: GetPaidTransactionSource.lightningAddress,
  invoiceId: null,
  amountSat: 2100,
  receivedAt: DateTime.utc(2026, 7, 18, 12),
  rail: GetPaidTransactionRail.lightning,
  settlementState: GetPaidSettlementState.settled,
  late: false,
  comment: null,
  settlement: settlement,
);

GetPaidSettlement _fiat({
  int? amountMinor = 12345,
  GetPaidSettlementLegStatus status = GetPaidSettlementLegStatus.settled,
}) => GetPaidSettlement(
  kind: GetPaidSettlementKind.fiat,
  fiat: [
    GetPaidFiatSettlementLeg(
      amountMinor: amountMinor,
      currency: 'CAD',
      orderId: '40000000-0000-4000-8000-000000000009',
      status: status,
    ),
  ],
);

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

Future<void> _pumpHistory(
  WidgetTester tester,
  List<GetPaidTransaction> transactions,
) async {
  final cubit = _StubHistoryCubit(
    GetPaidTransactionHistoryState(
      status: GetPaidTransactionHistoryStatus.loaded,
      transactions: transactions,
    ),
  );
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
}

Future<void> _pumpDetail(
  WidgetTester tester,
  GetPaidTransaction transaction,
) async {
  await tester.pumpWidget(
    _app(GetPaidTransactionDetailScreen(transaction: transaction)),
  );
  await tester.pump();
}

void main() {
  group('history label', () {
    testWidgets('renders explicit bitcoin / fiat / mixed labels', (
      tester,
    ) async {
      await _pumpHistory(tester, [
        _tx(
          settlement: const GetPaidSettlement(
            kind: GetPaidSettlementKind.bitcoin,
          ),
        ),
      ]);
      expect(find.text('Bitcoin'), findsOneWidget);

      await _pumpHistory(tester, [_tx(settlement: _fiat())]);
      expect(find.text('Fiat'), findsOneWidget);

      await _pumpHistory(tester, [
        _tx(
          settlement: const GetPaidSettlement(
            kind: GetPaidSettlementKind.mixed,
          ),
        ),
      ]);
      expect(find.text('Mixed'), findsOneWidget);
    });

    testWidgets(
      'unavailable shows the explicit unavailable label, never Bitcoin',
      (tester) async {
        await _pumpHistory(tester, [
          _tx(
            settlement: const GetPaidSettlement(
              kind: GetPaidSettlementKind.unavailable,
            ),
          ),
        ]);
        expect(find.text('Settlement details unavailable'), findsOneWidget);
        expect(find.text('Bitcoin'), findsNothing);
      },
    );

    testWidgets('a no-data row omits the classification label entirely', (
      tester,
    ) async {
      await _pumpHistory(tester, [_tx(settlement: null)]);
      expect(find.text('Bitcoin'), findsNothing);
      expect(find.text('Fiat'), findsNothing);
      expect(find.text('Mixed'), findsNothing);
      expect(find.text('Settlement details unavailable'), findsNothing);
    });
  });

  group('detail settlement section', () {
    testWidgets('renders a settled fiat leg with amount, status and order id', (
      tester,
    ) async {
      await _pumpDetail(tester, _tx(settlement: _fiat()));
      expect(find.text('123.45 CAD'), findsOneWidget);
      expect(find.text('Settled'), findsWidgets);
      expect(find.text('40000000-0000-4000-8000-000000000009'), findsOneWidget);
    });

    testWidgets('renders a mixed settlement with a bitcoin portion', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _tx(
          settlement: GetPaidSettlement(
            kind: GetPaidSettlementKind.mixed,
            bitcoin: const [
              GetPaidBitcoinSettlementLeg(
                amountSat: 60000,
                status: GetPaidSettlementLegStatus.settled,
              ),
            ],
            fiat: _fiat().fiat,
          ),
        ),
      );
      expect(find.text('60,000 sats'), findsOneWidget);
      expect(find.text('123.45 CAD'), findsOneWidget);
    });

    testWidgets('renders distinct copy per override reason', (tester) async {
      Future<void> pumpOverride(GetPaidFiatOverrideReason reason) =>
          _pumpDetail(
            tester,
            _tx(
              settlement: GetPaidSettlement(
                kind: GetPaidSettlementKind.bitcoin,
                overrideReason: reason,
              ),
            ),
          );

      await pumpOverride(GetPaidFiatOverrideReason.belowMinimum);
      expect(find.textContaining('below Bull Bitcoin'), findsOneWidget);

      await pumpOverride(GetPaidFiatOverrideReason.invalidSplit);
      expect(
        find.textContaining('fiat split could not be applied'),
        findsOneWidget,
      );

      await pumpOverride(GetPaidFiatOverrideReason.conversionUnavailable);
      expect(
        find.textContaining('fiat conversion was unavailable'),
        findsOneWidget,
      );

      await pumpOverride(GetPaidFiatOverrideReason.unknown);
      expect(find.textContaining('could not be applied'), findsOneWidget);
    });

    testWidgets('renders an unavailable settlement note', (tester) async {
      await _pumpDetail(
        tester,
        _tx(
          settlement: const GetPaidSettlement(
            kind: GetPaidSettlementKind.unavailable,
          ),
        ),
      );
      expect(find.text('Settlement details unavailable'), findsOneWidget);
    });

    testWidgets('plain bitcoin with no override shows no settlement section', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _tx(
          settlement: const GetPaidSettlement(
            kind: GetPaidSettlementKind.bitcoin,
          ),
        ),
      );
      // The section title is only rendered when there is something to explain.
      expect(find.text('Fiat conversion'), findsNothing);
    });
  });
}
