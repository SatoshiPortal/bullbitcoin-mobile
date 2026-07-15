import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoices_list_screen.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/invoice_list_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// A stub cubit seeded with a fixed state; the actions are no-ops so the screen
// renders the seeded status without a locator or network.
class _StubListCubit extends Cubit<InvoicesListState>
    implements InvoicesListCubit {
  _StubListCubit(super.initialState);

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  void setFilter(InvoiceStatus? filter) {}
}

Invoice _invoice(
  String id,
  InvoiceStatus status, {
  InvoiceFallbackState? fallbackState,
  InvoiceSettlementState settlementState = InvoiceSettlementState.none,
  DateTime? paidAt,
  DateTime? expiresAt,
}) => Invoice(
  id: InvoiceId(id),
  status: status,
  settlementState: settlementState,
  amountSat: 1000,
  remainingAmountSat: 1000,
  acceptBtc: false,
  acceptLn: false,
  acceptLiquid: true,
  createdAt: DateTime.utc(2026),
  expiresAt: expiresAt ?? DateTime.utc(2030),
  paidAt: paidAt,
  fallbackSupervisions: fallbackState == null
      ? const []
      : [
          InvoiceFallbackSupervision(
            invoiceId: InvoiceId(id),
            nym: 'merchant',
            state: fallbackState,
            payerAmountSat: 105000,
            invoiceSwapAmountSat: 100000,
            lockupAddress: 'bc1plockup',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        ],
);

Future<void> _pump(WidgetTester tester, InvoicesListState state) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<InvoicesListCubit>.value(
        value: _StubListCubit(state),
        child: const InvoicesListScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('loading shows the shimmer placeholder', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(status: InvoicesListStatus.loading),
    );
    expect(find.byType(LoadingBoxContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty loaded state shows the empty copy', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(status: InvoicesListStatus.loaded),
    );
    expect(find.byType(InvoiceListItem), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loaded list renders one row per invoice', (tester) async {
    await _pump(
      tester,
      InvoicesListState(
        status: InvoicesListStatus.loaded,
        invoices: [
          _invoice('a', InvoiceStatus.unpaid),
          _invoice('b', InvoiceStatus.paid),
        ],
      ),
    );
    expect(find.byType(InvoiceListItem), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders invoice-linked fallback state without an action', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoicesListState(
        status: InvoicesListStatus.loaded,
        invoices: [
          _invoice(
            'a',
            InvoiceStatus.paid,
            fallbackState: InvoiceFallbackState.confirming,
          ),
        ],
      ),
    );

    expect(find.text('Settlement pending — Bitcoin fallback'), findsOneWidget);
    expect(find.textContaining('Recover'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows paid as provisional until settlement is final', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoicesListState(
        status: InvoicesListStatus.loaded,
        invoices: [
          _invoice(
            'a',
            InvoiceStatus.paid,
            settlementState: InvoiceSettlementState.pending,
          ),
        ],
      ),
    );

    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Settlement pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a late payment on its original invoice row', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoicesListState(
        status: InvoicesListStatus.loaded,
        invoices: [
          _invoice(
            'original-invoice',
            InvoiceStatus.paid,
            paidAt: DateTime.utc(2030, 1, 2),
            expiresAt: DateTime.utc(2030, 1, 1),
          ),
        ],
      ),
    );

    expect(find.text('original-invoice'), findsOneWidget);
    expect(find.text('Late payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders calm unavailable and overflow supervision notices', (
    tester,
  ) async {
    await _pump(
      tester,
      const InvoicesListState(
        status: InvoicesListStatus.loaded,
        fallbackSupervisionUnavailable: true,
        fallbackSupervisionOverflow: true,
      ),
    );

    expect(
      find.text('Automatic fallback status is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Some automatic fallback payments are not shown. Contact support.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error state renders without throwing', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(
        status: InvoicesListStatus.error,
        failure: InvoicesFailure.network(),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
