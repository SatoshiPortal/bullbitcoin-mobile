import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/usecases/get_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayService extends Mock implements InvoicesPayServicePort {}

void main() {
  setUpAll(() {
    registerFallbackValue(InvoiceId('x'));
  });

  late _MockPayService payService;
  late GetInvoiceUsecase usecase;

  setUp(() {
    payService = _MockPayService();
    usecase = GetInvoiceUsecase(payService: payService);
  });

  InvoiceStatusSnapshot snapshot(InvoiceStatus status) => InvoiceStatusSnapshot(
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

  test('fetches the UNSIGNED status by id (no signer resolved here)', () async {
    when(() => payService.getInvoiceStatus(any())).thenAnswer(
      (_) async => snapshot(InvoiceStatus.unpaid),
    );

    final result = await usecase.execute(InvoiceId('inv-1'));

    expect(result.status, InvoiceStatus.unpaid);
    verify(() => payService.getInvoiceStatus(InvoiceId('inv-1'))).called(1);
  });

  test('an unknown id surfaces as notFound', () async {
    when(() => payService.getInvoiceStatus(any()))
        .thenThrow(const InvoicesException.notFound());

    await expectLater(
      usecase.execute(InvoiceId('missing')),
      throwsA(
        isA<InvoicesException>().having(
          (e) => e.kind,
          'kind',
          InvoicesErrorKind.notFound,
        ),
      ),
    );
  });
}
