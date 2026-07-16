import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_pay_service_datasource.dart';
import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullnym extends Mock implements BullnymFacade {}

T _unwrap<T>(Result<T, InvoicesFailure> result) => result.fold(
  (value) => value,
  (failure) => throw TestFailure('expected Ok, got $failure'),
);

InvoicesFailure _unwrapFailure<T>(Result<T, InvoicesFailure> result) =>
    result.fold(
      (_) => throw TestFailure('expected Err, got Ok'),
      (failure) => failure,
    );

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
        clientRequestId: '00000000-0000-4000-8000-000000000001',
        presentationEnvelope: 'envelope',
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
    datasource = InvoicesPayServiceDatasource(
      bullnym: bullnym,
      expectedOrigin: Uri.parse('https://bullpay.ca'),
    );
  });

  PreparedPrivateInvoiceCreate createOperation({String? linkToPageNym}) =>
      PreparedPrivateInvoiceCreate(
        encrypted: EncryptedPrivateInvoice(
          clientRequestId: '00000000-0000-4000-8000-000000000001',
          presentationEnvelope: 'E' * 5500,
          viewingKey: 'A' * 43,
        ),
        amountSat: 2500,
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
        liquidAddress: 'lq1qfresh',
        liquidBlindingKeyHex: 'de' * 32,
        expiresAtUnix: DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000,
        linkToPageNym: linkToPageNym,
      );

  group('createInvoice', () {
    Future<InvoicesFailure> mapCreateFailure(BullnymFailure error) async {
      when(
        () => bullnym.createInvoice(
          signer: any(named: 'signer'),
          nym: any(named: 'nym'),
          fields: any(named: 'fields'),
        ),
      ).thenAnswer((_) async => Err(error));

      return _unwrapFailure(
        await datasource.createInvoice(
          signer: signer,
          operation: createOperation(),
        ),
      );
    }

    test(
      'maps the prepared operation to opaque wire fields and private link',
      () async {
        when(
          () => bullnym.createInvoice(
            signer: any(named: 'signer'),
            nym: any(named: 'nym'),
            fields: any(named: 'fields'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            BullnymCreateInvoiceResponse(
              invoiceId: 'inv-1',
              invoiceUrl: 'https://bullpay.ca/invoice/inv-1',
            ),
          ),
        );

        final result = _unwrap(
          await datasource.createInvoice(
            signer: signer,
            operation: createOperation(),
          ),
        );

        expect(result.invoiceId.value, 'inv-1');
        expect(
          result.privateLink.value,
          'https://bullpay.ca/invoice/inv-1#v1.${'A' * 43}',
        );

        // Unlinked v1: nym is null (matched literally), and we capture the fields.
        final fields =
            verify(
                  () => bullnym.createInvoice(
                    signer: any(named: 'signer'),
                    nym: null,
                    fields: captureAny(named: 'fields'),
                  ),
                ).captured.single
                as BullnymCreateInvoiceFields;
        expect(fields.amountSat, 2500);
        expect(
          fields.clientRequestId,
          createOperation().encrypted.clientRequestId,
        );
        expect(
          fields.presentationEnvelope,
          createOperation().encrypted.presentationEnvelope,
        );
        expect(fields.liquidAddress, 'lq1qfresh');
        expect(fields.liquidBlindingKeyHex, 'de' * 32);
        expect(
          fields.expiresAtUnix,
          DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000,
        );
      },
    );

    test(
      'a non-HTTPS invoice_url is rejected as invalidServerResponse',
      () async {
        when(
          () => bullnym.createInvoice(
            signer: any(named: 'signer'),
            nym: any(named: 'nym'),
            fields: any(named: 'fields'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            BullnymCreateInvoiceResponse(
              invoiceId: 'inv-1',
              invoiceUrl: 'http://evil.example/invoice/inv-1',
            ),
          ),
        );

        final failure = _unwrapFailure(
          await datasource.createInvoice(
            signer: signer,
            operation: createOperation(),
          ),
        );
        expect(failure.kind, InvoicesFailureKind.invalidServerResponse);
      },
    );

    test('maps every stable invoice server code to its failure', () async {
      Future<InvoicesFailure> fromCode(String code, {bool retryable = false}) =>
          mapCreateFailure(
            BullnymFailure.serverRejectedRequest(
              code: code,
              logMessage: 'diagnostic only',
              retryable: retryable,
            ),
          );

      expect(
        (await fromCode('InvoiceNotFound')).kind,
        InvoicesFailureKind.notFound,
      );
      expect(
        (await fromCode('InvalidAmount')).kind,
        InvoicesFailureKind.invalidInput,
      );
      expect((await fromCode('AuthError')).kind, InvoicesFailureKind.authError);
      expect(
        (await fromCode('BitcoinAddressAlreadyUsed')).kind,
        InvoicesFailureKind.reusedBitcoinAddress,
      );
      expect(
        (await fromCode('LiquidAddressAlreadyUsed')).kind,
        InvoicesFailureKind.reusedLiquidAddress,
      );
      expect(
        (await fromCode('InvoiceCreateConflict')).kind,
        InvoicesFailureKind.createConflict,
      );
      for (final code in const [
        'RateLimitedSender',
        'RateLimitedRecipient',
        'RateLimitedNetwork',
      ]) {
        expect((await fromCode(code)).kind, InvoicesFailureKind.rateLimited);
      }

      final knownServer = await fromCode('ServiceUnavailable', retryable: true);
      expect(knownServer.kind, InvoicesFailureKind.server);
      expect(knownServer.retryable, isTrue);
      expect((await fromCode('SomethingNew')).kind, InvoicesFailureKind.server);
    });

    test(
      'maps transport and fail-closed failures without diagnostics',
      () async {
        expect(
          (await mapCreateFailure(
            const BullnymFailure.network(logMessage: 'secret-network'),
          )).kind,
          InvoicesFailureKind.network,
        );
        expect(
          (await mapCreateFailure(
            const BullnymFailure.timeout(logMessage: 'secret-timeout'),
          )).kind,
          InvoicesFailureKind.timeout,
        );

        final failClosed = await mapCreateFailure(
          const BullnymFailure.unexpectedHttpStatus(statusCode: 404),
        );
        expect(failClosed.kind, InvoicesFailureKind.server);
        expect(failClosed.retryable, isTrue);

        expect(
          (await mapCreateFailure(
            const BullnymFailure.invalidServerResponse(),
          )).kind,
          InvoicesFailureKind.invalidServerResponse,
        );
        expect(
          (await mapCreateFailure(const BullnymFailure.signingFailed())).kind,
          InvoicesFailureKind.signingFailed,
        );

        final sanitized = await mapCreateFailure(
          const BullnymFailure.serverRejectedRequest(
            code: 'InvalidAmount',
            logMessage: 'secret-diagnostic-detail',
            retryable: false,
          ),
        );
        expect(
          sanitized.toString(),
          isNot(contains('secret-diagnostic-detail')),
        );
      },
    );

    test('preserves the server reason on logMessage for a rejected liquid '
        'blinding key without leaking it into toString', () async {
      final mapped = await mapCreateFailure(
        const BullnymFailure.serverRejectedRequest(
          code: 'InvalidAmount',
          logMessage: 'liquid_blinding_key_hex: invalid secret key',
          retryable: false,
        ),
      );

      // The server buckets every create-time field validation under the
      // `InvalidAmount` code, so the kind stays invalidInput...
      expect(mapped.kind, InvoicesFailureKind.invalidInput);
      // ...but the specific reason must remain recoverable for logs/Sentry so
      // a blinding-key rejection is not mistaken for an amount rejection.
      expect(mapped.logMessage, 'liquid_blinding_key_hex: invalid secret key');
      // The diagnostic reason still never leaks through toString (UI-facing).
      expect(mapped.toString(), 'InvoicesFailure(InvalidAmount)');
      expect(mapped.toString(), isNot(contains('secret key')));
    });

    test(
      'maps an unexpected recoverable exception without leaking it',
      () async {
        when(
          () => bullnym.createInvoice(
            signer: any(named: 'signer'),
            nym: any(named: 'nym'),
            fields: any(named: 'fields'),
          ),
        ).thenThrow(const FormatException('diagnostic-only'));

        final failure = _unwrapFailure(
          await datasource.createInvoice(
            signer: signer,
            operation: createOperation(),
          ),
        );

        expect(failure.kind, InvoicesFailureKind.unexpected);
        expect(failure.toString(), isNot(contains('diagnostic-only')));
      },
    );
  });

  group('getInvoiceStatus (unsigned)', () {
    test(
      'maps the status DTO → snapshot with unix→DateTime conversions',
      () async {
        when(
          () => bullnym.getInvoiceStatus(invoiceId: any(named: 'invoiceId')),
        ).thenAnswer(
          (_) async => const Ok(
            BullnymInvoiceStatus(
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
              bitcoinDirectObservations: [],
            ),
          ),
        );

        final snapshot = _unwrap(
          await datasource.getInvoiceStatus(InvoiceId('inv-1')),
        );

        expect(snapshot.status, InvoiceStatus.paid);
        expect(snapshot.paidVia, PaymentMethod.lightning);
        expect(snapshot.paidAmountSat, 1000);
        expect(snapshot.expiresAt.isUtc, isTrue);
        verify(() => bullnym.getInvoiceStatus(invoiceId: 'inv-1')).called(1);
      },
    );

    test('a bullnym error maps to notFound', () async {
      when(
        () => bullnym.getInvoiceStatus(invoiceId: any(named: 'invoiceId')),
      ).thenAnswer(
        (_) async => const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'InvoiceNotFound',
            logMessage: 'no such invoice',
            statusCode: 404,
            retryable: false,
          ),
        ),
      );

      final failure = _unwrapFailure(
        await datasource.getInvoiceStatus(InvoiceId('missing')),
      );
      expect(failure.kind, InvoicesFailureKind.notFound);
    });

    test(
      'maps an unknown wire status to unsupported fail-closed state',
      () async {
        when(
          () => bullnym.getInvoiceStatus(invoiceId: any(named: 'invoiceId')),
        ).thenAnswer(
          (_) async => const Ok(
            BullnymInvoiceStatus(
              status: 'needs_manual_reconciliation',
              pricingMode: 'sat',
              settlementStatus: 'pending',
              amountSat: 1000,
              remainingAmountSat: 1000,
              paymentToleranceSat: 5,
              rateLocksUntilUnix: 1893456000,
              expiresAtUnix: 1893456000,
              acceptBtc: true,
              acceptLn: true,
              acceptLiquid: true,
              bitcoinDirectObservations: [],
            ),
          ),
        );

        final snapshot = _unwrap(
          await datasource.getInvoiceStatus(InvoiceId('inv-1')),
        );

        expect(snapshot.status, InvoiceStatus.unsupported);
        expect(snapshot.status.isTerminal, isFalse);
        expect(snapshot.isCancellable, isFalse);
      },
    );
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
        (_) async => const Ok(
          BullnymListInvoicesResponse(
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
        ),
      );

      final result = _unwrap(
        await datasource.listInvoices(
          signer: signer,
          command: const ListInvoicesCommand(),
        ),
      );

      expect(result.invoices, hasLength(1));
      expect(result.invoices.single.id.value, 'inv-1');
      expect(result.invoices.single.status, InvoiceStatus.unpaid);
      expect(result.invoices.single.nymOwner, isNull);
      expect(result.hasMore, isFalse);
    });

    test(
      'maps unknown list item status to unsupported fail-closed state',
      () async {
        when(
          () => bullnym.listInvoices(
            signer: any(named: 'signer'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            status: any(named: 'status'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            BullnymListInvoicesResponse(
              invoices: [
                BullnymInvoiceListItem(
                  id: 'inv-1',
                  origin: 'wallet',
                  status: 'requires_operator_review',
                  pricingMode: 'sat',
                  settlementStatus: 'pending',
                  amountSat: 1000,
                  remainingAmountSat: 1000,
                  acceptBtc: true,
                  acceptLn: true,
                  acceptLiquid: true,
                  createdAtUnix: 1893450000,
                  expiresAtUnix: 1893456000,
                ),
              ],
              page: 1,
              pageSize: 100,
              hasMore: false,
            ),
          ),
        );

        final result = _unwrap(
          await datasource.listInvoices(
            signer: signer,
            command: const ListInvoicesCommand(),
          ),
        );

        final status = result.invoices.single.status;
        expect(status, InvoiceStatus.unsupported);
        expect(result.invoices.single.isCancellable, isFalse);
      },
    );
  });
}
