import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
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
}
