import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

InvoiceStatusSnapshot _snapshot(InvoiceStatus status) => InvoiceStatusSnapshot(
  status: status,
  pricingMode: 'sat',
  settlementStatus: 'pending',
  amountSat: 1000,
  remainingAmountSat: 1000,
  paymentToleranceSat: 0,
  rateLocksUntil: DateTime.utc(2030),
  expiresAt: DateTime.utc(2030),
  acceptBtc: false,
  acceptLn: false,
  acceptLiquid: true,
);

InvoiceFallbackSupervision _fallback(InvoiceFallbackState state) =>
    InvoiceFallbackSupervision(
      invoiceId: InvoiceId('inv-1'),
      nym: 'merchant',
      state: state,
      payerAmountSat: 105000,
      invoiceSwapAmountSat: 100000,
      lockupAddress: 'bc1plockup',
      transactionId: 'ab' * 32,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(InvoiceId('x'));
    registerFallbackValue(CancelInvoiceCommand(invoiceId: InvoiceId('x')));
  });

  late _MockFacade facade;

  setUp(() {
    facade = _MockFacade();
    when(() => facade.fallbackSupervision()).thenAnswer(
      (_) async => const Ok(InvoiceFallbackOverview(items: [], hasMore: false)),
    );
  });

  InvoiceDetailCubit build({
    Duration initial = const Duration(milliseconds: 5),
    Duration max = const Duration(milliseconds: 20),
  }) => InvoiceDetailCubit(
    facade: facade,
    invoiceId: InvoiceId('inv-1'),
    pollInitialDelay: initial,
    pollMaxDelay: max,
  );

  test(
    'load fetches the status; a terminal status starts NO poll loop',
    () async {
      when(
        () => facade.status(any()),
      ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.paid)));

      final cubit = build();
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cubit.state.status, InvoiceDetailStatus.loaded);
      expect(cubit.state.isTerminal, isTrue);
      verify(() => facade.status(any())).called(1); // no polling after terminal
      await cubit.close();
    },
  );

  test('polls while non-terminal, then STOPS on a terminal status', () async {
    var call = 0;
    when(() => facade.status(any())).thenAnswer((_) async {
      call++;
      return Ok(
        _snapshot(call == 1 ? InvoiceStatus.unpaid : InvoiceStatus.paid),
      );
    });

    final cubit = build();
    await cubit.load();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // one initial fetch + one poll that observed the terminal status.
    verify(() => facade.status(any())).called(2);
    expect(cubit.state.isTerminal, isTrue);
    await cubit.close();
  });

  test('a terminal invoice keeps polling while fallback confirms', () async {
    var statusCalls = 0;
    when(() => facade.status(any())).thenAnswer((_) async {
      statusCalls++;
      return Ok(_snapshot(InvoiceStatus.paid));
    });
    when(() => facade.fallbackSupervision()).thenAnswer(
      (_) async => Ok(
        InvoiceFallbackOverview(
          items: [_fallback(InvoiceFallbackState.confirming)],
          hasMore: false,
        ),
      ),
    );

    final cubit = build();
    await cubit.load();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(cubit.state.isTerminal, isFalse);
    expect(statusCalls, greaterThan(1));
    await cubit.close();
  });

  test(
    'a supervision failure keeps the loaded invoice snapshot visible',
    () async {
      when(
        () => facade.status(any()),
      ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.paid)));
      when(
        () => facade.fallbackSupervision(),
      ).thenAnswer((_) async => const Err(InvoicesFailure.network()));

      final cubit = build(initial: const Duration(seconds: 30));
      await cubit.load();

      expect(cubit.state.status, InvoiceDetailStatus.loaded);
      expect(cubit.state.snapshot, isNotNull);
      expect(
        cubit.state.fallbackSupervisionFailure?.kind,
        InvoicesFailureKind.network,
      );
      await cubit.close();
    },
  );

  test('dispose stops the poll loop (no post-dispose fetch)', () async {
    when(
      () => facade.status(any()),
    ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.unpaid)));

    final cubit = build();
    await cubit.load(); // initial fetch (1), poll scheduled for +5ms
    await cubit.close(); // invalidate before the poll fires
    await Future<void>.delayed(const Duration(milliseconds: 40));

    verify(() => facade.status(any())).called(1);
  });

  test(
    'cancel stores the final status SEPARATELY from the polled snapshot',
    () async {
      when(
        () => facade.status(any()),
      ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.unpaid)));
      when(() => facade.cancel(any())).thenAnswer(
        (_) async => Ok(
          CancelInvoiceResult(
            invoiceId: InvoiceId('inv-1'),
            finalStatus: InvoiceStatus.cancelled,
          ),
        ),
      );

      // A long poll delay keeps the loop from interfering with the assertions.
      final cubit = build(initial: const Duration(seconds: 30));
      await cubit.load();
      expect(cubit.state.canCancel, isTrue); // unpaid → cancellable (DG-I5)

      await cubit.cancel();

      expect(cubit.state.cancelFinalStatus, InvoiceStatus.cancelled);
      // The snapshot is NOT overwritten by the cancel result (§3.11)...
      expect(cubit.state.snapshot?.status, InvoiceStatus.unpaid);
      // ...but the effective status reflects the settled cancel.
      expect(cubit.state.effectiveStatus, InvoiceStatus.cancelled);
      expect(cubit.state.canCancel, isFalse);
      await cubit.close();
    },
  );

  test('cancel is inert once a final status exists', () async {
    when(
      () => facade.status(any()),
    ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.unpaid)));
    when(() => facade.cancel(any())).thenAnswer(
      (_) async => Ok(
        CancelInvoiceResult(
          invoiceId: InvoiceId('inv-1'),
          finalStatus: InvoiceStatus.cancelled,
        ),
      ),
    );

    final cubit = build(initial: const Duration(seconds: 30));
    await cubit.load();
    await cubit.cancel();
    await cubit.cancel(); // canCancel is now false → inert

    verify(() => facade.cancel(any())).called(1);
    await cubit.close();
  });
}
