import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/cancel_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIdentity extends Mock implements InvoicesIdentityPort {}

class _MockPayService extends Mock implements InvoicesPayServicePort {}

void main() {
  final signer = BullnymAuthSigner(
    npubHex: 'aa' * 32,
    signHashHex: (_) => 'bb' * 64,
  );

  setUpAll(() {
    registerFallbackValue(
      BullnymAuthSigner(npubHex: '00' * 32, signHashHex: (_) => ''),
    );
    registerFallbackValue(
      CancelInvoiceCommand(invoiceId: InvoiceId('x')),
    );
  });

  late _MockIdentity identity;
  late _MockPayService payService;
  late CancelInvoiceUsecase usecase;

  setUp(() {
    identity = _MockIdentity();
    payService = _MockPayService();
    usecase = CancelInvoiceUsecase(identity: identity, payService: payService);
    when(() => identity.getSigningHandle()).thenAnswer((_) async => signer);
  });

  test('resolves the signer then delegates, returning the final status',
      () async {
    when(
      () => payService.cancelInvoice(
        signer: any(named: 'signer'),
        command: any(named: 'command'),
      ),
    ).thenAnswer(
      (_) async => CancelInvoiceResult(
        invoiceId: InvoiceId('inv-1'),
        finalStatus: InvoiceStatus.cancelled,
      ),
    );

    final result = await usecase.execute(
      CancelInvoiceCommand(invoiceId: InvoiceId('inv-1')),
    );

    expect(result.finalStatus, InvoiceStatus.cancelled);
    verify(() => identity.getSigningHandle()).called(1);
    verify(
      () => payService.cancelInvoice(signer: signer, command: any(named: 'command')),
    ).called(1);
  });

  test('ownership rejection surfaces as notFound (server 404-as-ownership)',
      () async {
    when(
      () => payService.cancelInvoice(
        signer: any(named: 'signer'),
        command: any(named: 'command'),
      ),
    ).thenThrow(const InvoicesException.notFound());

    await expectLater(
      usecase.execute(CancelInvoiceCommand(invoiceId: InvoiceId('foreign'))),
      throwsA(
        isA<InvoicesException>().having(
          (e) => e.kind,
          'kind',
          InvoicesErrorKind.notFound,
        ),
      ),
    );
  });

  test('a benign already-terminal cancel returns its pre-existing status',
      () async {
    when(
      () => payService.cancelInvoice(
        signer: any(named: 'signer'),
        command: any(named: 'command'),
      ),
    ).thenAnswer(
      (_) async => CancelInvoiceResult(
        invoiceId: InvoiceId('inv-1'),
        finalStatus: InvoiceStatus.expired,
      ),
    );

    final result = await usecase.execute(
      CancelInvoiceCommand(invoiceId: InvoiceId('inv-1')),
    );

    expect(result.finalStatus, InvoiceStatus.expired);
  });
}
