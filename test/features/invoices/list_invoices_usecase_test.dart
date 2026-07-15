import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
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
    registerFallbackValue(const ListInvoicesCommand());
  });

  late _MockIdentity identity;
  late _MockPayService payService;
  late ListInvoicesUsecase usecase;

  setUp(() {
    identity = _MockIdentity();
    payService = _MockPayService();
    usecase = ListInvoicesUsecase(identity: identity, payService: payService);
    when(() => identity.getSigningHandle()).thenAnswer((_) async => Ok(signer));
    when(
      () => payService.listFallbackSupervision(signer: any(named: 'signer')),
    ).thenAnswer(
      (_) async => const Ok(InvoiceFallbackOverview(items: [], hasMore: false)),
    );
  });

  test(
    'resolves the signer then passes page/pageSize/status through',
    () async {
      when(
        () => payService.listInvoices(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ListInvoicesResult(
            invoices: [],
            page: 2,
            pageSize: 50,
            hasMore: true,
          ),
        ),
      );

      final result =
          (await usecase.execute(
            const ListInvoicesCommand(
              page: 2,
              pageSize: 50,
              status: InvoiceStatus.unpaid,
            ),
          )).fold(
            (value) => value,
            (failure) => throw TestFailure('expected Ok, got $failure'),
          );

      expect(result.page, 2);
      expect(result.pageSize, 50);
      expect(result.hasMore, isTrue);

      final captured =
          verify(
                () => payService.listInvoices(
                  signer: signer,
                  command: captureAny(named: 'command'),
                ),
              ).captured.single
              as ListInvoicesCommand;
      expect(captured.page, 2);
      expect(captured.pageSize, 50);
      expect(captured.status, InvoiceStatus.unpaid);
    },
  );

  test('defaults are page=1, pageSize=100, no status filter (v1)', () async {
    const command = ListInvoicesCommand();
    expect(command.page, 1);
    expect(command.pageSize, 100);
    expect(command.status, isNull);
  });

  test('attaches every swap row to its original invoice', () async {
    final invoice = Invoice(
      id: InvoiceId('inv-1'),
      status: InvoiceStatus.expired,
      amountSat: 100000,
      remainingAmountSat: 100000,
      acceptBtc: true,
      acceptLn: false,
      acceptLiquid: false,
      createdAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2026, 2),
    );
    when(
      () => payService.listInvoices(
        signer: any(named: 'signer'),
        command: any(named: 'command'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        ListInvoicesResult(
          invoices: [invoice],
          page: 1,
          pageSize: 100,
          hasMore: false,
        ),
      ),
    );
    when(
      () => payService.listFallbackSupervision(signer: any(named: 'signer')),
    ).thenAnswer(
      (_) async => Ok(
        InvoiceFallbackOverview(
          items: [
            InvoiceFallbackSupervision(
              invoiceId: InvoiceId('inv-1'),
              nym: 'merchant',
              state: InvoiceFallbackState.confirming,
              payerAmountSat: 105000,
              invoiceSwapAmountSat: 100000,
              lockupAddress: 'bc1plockup',
              transactionId: 'ab' * 32,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026, 1, 2),
            ),
          ],
          hasMore: true,
        ),
      ),
    );

    final result = (await usecase.execute(const ListInvoicesCommand())).fold(
      (value) => value,
      (failure) => throw TestFailure('expected Ok, got $failure'),
    );

    expect(result.invoices.single.fallbackSupervisions, hasLength(1));
    expect(
      result.invoices.single.fallbackState,
      InvoiceFallbackState.confirming,
    );
    expect(result.fallbackSupervisionOverflow, isTrue);
  });

  test(
    'keeps the invoice list visible when supervision is unavailable',
    () async {
      when(
        () => payService.listInvoices(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
        ),
      ).thenAnswer(
        (_) async => const Ok(
          ListInvoicesResult(
            invoices: [],
            page: 1,
            pageSize: 100,
            hasMore: false,
          ),
        ),
      );
      when(
        () => payService.listFallbackSupervision(signer: any(named: 'signer')),
      ).thenAnswer((_) async => const Err(InvoicesFailure.network()));

      final result = (await usecase.execute(const ListInvoicesCommand())).fold(
        (value) => value,
        (failure) => throw TestFailure('expected Ok, got $failure'),
      );

      expect(result.invoices, isEmpty);
      expect(result.fallbackSupervisionUnavailable, isTrue);
    },
  );
}
