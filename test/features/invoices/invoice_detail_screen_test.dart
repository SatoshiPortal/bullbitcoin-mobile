import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoice_detail_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDetailCubit extends Cubit<InvoiceDetailState>
    implements InvoiceDetailCubit {
  _StubDetailCubit(super.initialState);

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> cancel() async {}
}

InvoicePaymentEvent _bitcoinPayment({
  required InvoicePaymentEventState state,
  required bool isLate,
  int confirmations = 0,
  int amountSat = 1200,
  InvoicePaymentProblem? problem,
}) {
  return InvoicePaymentEvent(
    rail: PaymentMethod.btc,
    amountSat: amountSat,
    firstSeenAt: DateTime.utc(2026, 2),
    lastSeenAt: DateTime.utc(2026, 2, 1, 0, 1),
    state: state,
    confirmations: confirmations,
    transactionId: 'ab' * 32,
    outputIndex: 1,
    isLate: isLate,
    problem: problem,
  );
}

InvoiceStatusSnapshot _historySnapshot({
  required InvoiceStatus status,
  required InvoiceSettlementState settlementState,
  required InvoicePaymentEvent payment,
  int paidAmountSat = 1000,
  int remainingAmountSat = 0,
}) {
  return InvoiceStatusSnapshot(
    status: status,
    settlementState: settlementState,
    pricingMode: 'sat',
    settlementStatus: 'ignored-after-domain-mapping',
    amountSat: 1000,
    remainingAmountSat: remainingAmountSat,
    paymentToleranceSat: 0,
    rateLocksUntil: DateTime.utc(2026, 1),
    expiresAt: DateTime.utc(2026, 1, 31),
    paidVia: PaymentMethod.btc,
    paidAt: DateTime.utc(2026, 2),
    paidAmountSat: paidAmountSat,
    acceptBtc: true,
    acceptLn: false,
    acceptLiquid: false,
    paymentEvents: [payment],
  );
}

InvoiceStatusSnapshot _privateLinkSnapshot(InvoiceStatus status) {
  return InvoiceStatusSnapshot(
    status: status,
    pricingMode: 'sat',
    settlementStatus: 'pending',
    amountSat: 1000,
    remainingAmountSat: 1000,
    paymentToleranceSat: 0,
    rateLocksUntil: DateTime.utc(2030),
    expiresAt: DateTime.utc(2030),
    lightningPr: 'lnbc1000',
    liquidAddress: 'lq1qaddress',
    bitcoinAddress: 'bc1qaddress',
    acceptBtc: true,
    acceptLn: true,
    acceptLiquid: true,
  );
}

Future<void> _pump(WidgetTester tester, InvoiceDetailState state) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cubit = _StubDetailCubit(state);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<InvoiceDetailCubit>.value(
        value: cubit,
        child: const InvoiceDetailScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows paid as provisional and attributes fallback to history', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _historySnapshot(
          status: InvoiceStatus.paid,
          settlementState: InvoiceSettlementState.pending,
          payment: _bitcoinPayment(
            state: InvoicePaymentEventState.pending,
            isLate: false,
          ),
        ),
        privateLinkLookupComplete: true,
        fallbackSupervisions: [
          InvoiceFallbackSupervision(
            invoiceId: InvoiceId('inv-1'),
            nym: 'merchant',
            state: InvoiceFallbackState.confirming,
            payerAmountSat: 1050,
            invoiceSwapAmountSat: 1000,
            lockupAddress: 'bc1plockup',
            fallbackAddress: 'bc1qmerchant',
            transactionId: 'cd' * 32,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        ],
      ),
    );

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Settlement pending'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Bitcoin payment'), findsOneWidget);
    expect(
      find.text('Payment received; awaiting confirmation'),
      findsOneWidget,
    );
    expect(find.text('Automatic Bitcoin fallback'), findsOneWidget);
    expect(find.textContaining('Recover'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows overpayment, late attribution and reorg evidence', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _historySnapshot(
          status: InvoiceStatus.overpaid,
          settlementState: InvoiceSettlementState.problem,
          paidAmountSat: 1200,
          payment: _bitcoinPayment(
            state: InvoicePaymentEventState.problem,
            isLate: true,
            problem: InvoicePaymentProblem.reorged,
          ),
        ),
        privateLinkLookupComplete: true,
      ),
    );

    expect(find.text('Overpaid'), findsOneWidget);
    expect(find.text('Settlement problem'), findsOneWidget);
    expect(find.text('Overpaid by'), findsOneWidget);
    expect(find.text('Late payment'), findsNWidgets(2));
    expect(
      find.text('Payment confirmation was reversed by a chain reorganization'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows partial received and remaining amounts', (tester) async {
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _historySnapshot(
          status: InvoiceStatus.partiallyPaid,
          settlementState: InvoiceSettlementState.pending,
          paidAmountSat: 400,
          remainingAmountSat: 600,
          payment: _bitcoinPayment(
            state: InvoicePaymentEventState.confirming,
            isLate: false,
            confirmations: 1,
            amountSat: 400,
          ),
        ),
        privateLinkLookupComplete: true,
      ),
    );

    expect(find.text('Partially paid'), findsOneWidget);
    expect(find.text('Received'), findsNWidgets(2));
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('1 confirmation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported status hides payment and private-link actions', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _privateLinkSnapshot(InvoiceStatus.unsupported),
        privateLinkLookupComplete: true,
      ),
    );

    expect(find.text('Update required'), findsOneWidget);
    expect(
      find.text(
        'Update the app, then refresh this invoice. Payment reconciliation '
        'may still be in progress.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel invoice'), findsNothing);
    expect(find.text('Private payment link'), findsNothing);
    expect(find.text('Lightning invoice'), findsNothing);
    expect(find.text('Liquid address'), findsNothing);
    expect(find.text('Bitcoin address'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained private link is the only sharing surface', (
    tester,
  ) async {
    final invoiceId = InvoiceId('inv-1');
    final link = PrivateInvoiceLink.fromServer(
      invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
      expectedInvoiceId: invoiceId,
      viewingKey: 'A' * 43,
      expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
    );
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _privateLinkSnapshot(InvoiceStatus.paid),
        privateLink: link,
        privateLinkLookupComplete: true,
      ),
    );

    expect(find.text('Private payment link'), findsOneWidget);
    expect(find.text('Copy private link'), findsOneWidget);
    expect(find.text('Share private link'), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);
    expect(find.text('Lightning invoice'), findsNothing);
    expect(find.text('Liquid address'), findsNothing);
    expect(find.text('Bitcoin address'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing retained link has no fragmentless fallback', (
    tester,
  ) async {
    await _pump(
      tester,
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        snapshot: _privateLinkSnapshot(InvoiceStatus.paid),
        privateLinkLookupComplete: true,
      ),
    );

    expect(
      find.text('Private link unavailable on this device'),
      findsOneWidget,
    );
    expect(find.text('Copy private link'), findsNothing);
    expect(find.text('Share private link'), findsNothing);
    expect(find.text('Open link'), findsNothing);
    expect(find.text('Lightning invoice'), findsNothing);
    expect(find.text('Liquid address'), findsNothing);
    expect(find.text('Bitcoin address'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
