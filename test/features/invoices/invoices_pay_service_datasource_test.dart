import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_pay_service_datasource.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullnym extends Mock implements BullnymFacade {}

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
      const BullnymCreateInvoiceFields(
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
      ),
    );
  });

  late _MockBullnym bullnym;
  late InvoicesPayServiceDatasource datasource;

  setUp(() {
    bullnym = _MockBullnym();
    datasource = InvoicesPayServiceDatasource(bullnym: bullnym);
  });

  CreateInvoiceCommand createCommand({String? linkToPageNym}) =>
      CreateInvoiceCommand(
        amountSat: 2500,
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
        expiresAt: DateTime.utc(2030, 1, 1),
        linkToPageNym: linkToPageNym,
      );

  group('createInvoice', () {
    test('maps the command → wire fields (unix expiry) and passes nym through',
        () async {
      when(
        () => bullnym.createInvoice(
          signer: any(named: 'signer'),
          nym: any(named: 'nym'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async => const BullnymCreateInvoiceResponse(
          invoiceId: 'inv-1',
          shareUrl: 'https://bullpay.ca/invoice/inv-1',
        ),
      );

      final result = await datasource.createInvoice(
        signer: signer,
        command: createCommand(),
        liquidAddress: 'lq1qfresh',
        liquidBlindingKeyHex: 'deadbeef',
      );

      expect(result.invoiceId.value, 'inv-1');
      expect(result.shareUrl.value, 'https://bullpay.ca/invoice/inv-1');

      // Unlinked v1: nym is null (matched literally), and we capture the fields.
      final fields = verify(
        () => bullnym.createInvoice(
          signer: any(named: 'signer'),
          nym: null,
          fields: captureAny(named: 'fields'),
        ),
      ).captured.single as BullnymCreateInvoiceFields;
      expect(fields.amountSat, 2500);
      expect(fields.liquidAddress, 'lq1qfresh');
      expect(fields.liquidBlindingKeyHex, 'deadbeef');
      expect(
        fields.expiresAtUnix,
        DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('a non-HTTPS share_url is rejected as invalidServerResponse (§8.8)',
        () async {
      when(
        () => bullnym.createInvoice(
          signer: any(named: 'signer'),
          nym: any(named: 'nym'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async => const BullnymCreateInvoiceResponse(
          invoiceId: 'inv-1',
          shareUrl: 'http://evil.example/invoice/inv-1',
        ),
      );

      await expectLater(
        datasource.createInvoice(
          signer: signer,
          command: createCommand(),
          liquidAddress: 'lq1qfresh',
          liquidBlindingKeyHex: 'deadbeef',
        ),
        throwsA(
          isA<InvoicesException>().having(
            (e) => e.kind,
            'kind',
            InvoicesErrorKind.invalidServerResponse,
          ),
        ),
      );
    });

    test('translates a BullnymException to the invoices family', () async {
      when(
        () => bullnym.createInvoice(
          signer: any(named: 'signer'),
          nym: any(named: 'nym'),
          fields: any(named: 'fields'),
        ),
      ).thenThrow(
        const BullnymException.serverRejectedRequest(
          code: 'InvalidAmount',
          diagnosticReason: 'amount too small',
          statusCode: 400,
          retryable: false,
        ),
      );

      await expectLater(
        datasource.createInvoice(
          signer: signer,
          command: createCommand(),
          liquidAddress: 'lq1qfresh',
          liquidBlindingKeyHex: 'deadbeef',
        ),
        throwsA(
          isA<InvoicesException>().having(
            (e) => e.kind,
            'kind',
            InvoicesErrorKind.invalidInput,
          ),
        ),
      );
    });
  });

  group('getInvoiceStatus (unsigned)', () {
    test('maps the status DTO → snapshot with unix→DateTime conversions',
        () async {
      when(() => bullnym.getInvoiceStatus(invoiceId: any(named: 'invoiceId')))
          .thenAnswer(
        (_) async => const BullnymInvoiceStatus(
          status: 'paid',
          pricingMode: 'sat',
          settlementStatus: 'settled',
          amountSat: 1000,
          remainingAmountSat: 0,
          paymentToleranceSat: 5,
          rateLocksUntilUnix: 1893456000,
          expiresAtUnix: 1893456000,
          paidVia: 'lightning',
          paidAtUnix: 1893450000,
          paidAmountSat: 1000,
          acceptBtc: false,
          acceptLn: true,
          acceptLiquid: true,
        ),
      );

      final snapshot = await datasource.getInvoiceStatus(InvoiceId('inv-1'));

      expect(snapshot.status, InvoiceStatus.paid);
      expect(snapshot.paidVia, PaymentMethod.lightning);
      expect(snapshot.paidAmountSat, 1000);
      expect(snapshot.expiresAt.isUtc, isTrue);
      verify(() => bullnym.getInvoiceStatus(invoiceId: 'inv-1')).called(1);
    });

    test('a bullnym error maps to notFound', () async {
      when(() => bullnym.getInvoiceStatus(invoiceId: any(named: 'invoiceId')))
          .thenThrow(
        const BullnymException.serverRejectedRequest(
          code: 'InvoiceNotFound',
          diagnosticReason: 'no such invoice',
          statusCode: 404,
          retryable: false,
        ),
      );

      await expectLater(
        datasource.getInvoiceStatus(InvoiceId('missing')),
        throwsA(
          isA<InvoicesException>().having(
            (e) => e.kind,
            'kind',
            InvoicesErrorKind.notFound,
          ),
        ),
      );
    });
  });

  group('listInvoices', () {
    test('maps list items → domain invoices and carries paging', () async {
      when(
        () => bullnym.listInvoices(
          signer: any(named: 'signer'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
        ),
      ).thenAnswer(
        (_) async => const BullnymListInvoicesResponse(
          invoices: [
            BullnymInvoiceListItem(
              id: 'inv-1',
              origin: 'wallet',
              status: 'unpaid',
              pricingMode: 'sat',
              settlementStatus: 'pending',
              amountSat: 1000,
              remainingAmountSat: 1000,
              acceptBtc: false,
              acceptLn: false,
              acceptLiquid: true,
              createdAtUnix: 1893450000,
              expiresAtUnix: 1893456000,
            ),
          ],
          page: 1,
          pageSize: 100,
          hasMore: false,
        ),
      );

      final result = await datasource.listInvoices(
        signer: signer,
        command: const ListInvoicesCommand(),
      );

      expect(result.invoices, hasLength(1));
      expect(result.invoices.single.id.value, 'inv-1');
      expect(result.invoices.single.status, InvoiceStatus.unpaid);
      expect(result.invoices.single.nymOwner, isNull);
      expect(result.hasMore, isFalse);
    });
  });
}
