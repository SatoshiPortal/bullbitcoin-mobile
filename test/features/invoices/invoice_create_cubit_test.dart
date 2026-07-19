import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

void main() {
  final invoiceId = InvoiceId('inv-1');
  final result = CreateInvoiceResult(
    invoiceId: invoiceId,
    privateLink: PrivateInvoiceLink.fromServer(
      invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
      expectedInvoiceId: invoiceId,
      viewingKey: 'A' * 43,
      expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
    ),
  );

  setUpAll(() {
    registerFallbackValue(
      CreateInvoiceCommand(
        amountSat: 1,
        presentation: PrivateInvoicePresentation(),
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
      ),
    );
  });

  late _MockFacade facade;

  setUp(() {
    facade = _MockFacade();
    when(() => facade.resumeCreate()).thenAnswer(
      (_) async => const Ok<CreateInvoiceResult?, InvoicesFailure>(null),
    );
    when(() => facade.supportedCurrencies()).thenAnswer(
      (_) async => const BullnymSupportedCurrencies(
        currencies: [
          BullnymSupportedCurrency(code: 'CAD', precision: 2),
          BullnymSupportedCurrency(code: 'COP', precision: 0),
        ],
      ),
    );
  });

  Future<InvoiceCreateCubit> initialized() async {
    final cubit = InvoiceCreateCubit(facade: facade);
    await cubit.initialize();
    return cubit;
  }

  test('sats submit builds encrypted presentation domain data', () async {
    when(() => facade.create(any())).thenAnswer((_) async => Ok(result));
    final cubit = await initialized();
    cubit.amountChanged('25000');
    cubit.detailChanged(InvoiceCreateField.payerName, ' Jane ');
    cubit.detailChanged(InvoiceCreateField.description, ' Design work ');
    cubit.detailChanged(InvoiceCreateField.invoiceDate, '2026-07-18');

    await cubit.submit();

    expect(cubit.state.result?.privateLink.value, contains('#v1.'));
    final sent =
        verify(() => facade.create(captureAny())).captured.single
            as CreateInvoiceCommand;
    expect(sent.amountSat, 25000);
    expect(sent.fiatAmountMinor, isNull);
    expect(sent.presentation.payer?.name, 'Jane');
    expect(sent.presentation.invoice?.description, 'Design work');
    expect(sent.presentation.invoice?.invoiceDate, '2026-07-18');
    await cubit.close();
  });

  test('fiat submit converts to minor units by currency precision', () async {
    when(() => facade.create(any())).thenAnswer((_) async => Ok(result));
    final cubit = await initialized();
    cubit.amountModeChanged(InvoiceAmountMode.fiat);
    cubit.fiatCurrencyChanged('CAD');
    cubit.amountChanged('12.34');

    await cubit.submit();

    final sent =
        verify(() => facade.create(captureAny())).captured.single
            as CreateInvoiceCommand;
    expect(sent.fiatAmountMinor, 1234);
    expect(sent.fiatCurrency, 'CAD');
    expect(sent.amountSat, isNull);
    await cubit.close();
  });

  test('invalid private date identifies the exact form field', () async {
    final cubit = await initialized();
    cubit.amountChanged('1000');
    cubit.detailChanged(InvoiceCreateField.paymentDeadline, '2025-02-29');

    await cubit.submit();

    expect(cubit.state.invalidField, InvoiceCreateField.paymentDeadline);
    expect(cubit.state.failure?.kind, InvoicesFailureKind.invalidInput);
    verifyNever(() => facade.create(any()));
    await cubit.close();
  });

  test('no rail selected is refused locally', () async {
    final cubit = await initialized();
    cubit.amountChanged('1000');
    cubit.acceptLnChanged(false);
    cubit.acceptLiquidChanged(false);

    await cubit.submit();

    expect(cubit.state.failure?.kind, InvoicesFailureKind.invalidInput);
    verifyNever(() => facade.create(any()));
    await cubit.close();
  });

  test('uncertain create locks the form into exact-operation retry', () async {
    when(
      () => facade.create(any()),
    ).thenAnswer((_) async => const Err(InvoicesFailure.outcomeUnknown()));
    var resumeCalls = 0;
    when(() => facade.resumeCreate()).thenAnswer((_) async {
      resumeCalls++;
      return resumeCalls == 1
          ? const Ok<CreateInvoiceResult?, InvoicesFailure>(null)
          : Ok<CreateInvoiceResult?, InvoicesFailure>(result);
    });
    final cubit = InvoiceCreateCubit(facade: facade);
    await cubit.initialize();
    cubit.amountChanged('1000');

    await cubit.submit();
    expect(cubit.state.pendingRetry, isTrue);
    await cubit.retryPending();

    expect(cubit.state.result, result);
    verify(() => facade.resumeCreate()).called(2);
    await cubit.close();
  });

  test(
    'startup resumes a pending operation before loading currencies',
    () async {
      when(() => facade.resumeCreate()).thenAnswer(
        (_) async => Ok<CreateInvoiceResult?, InvoicesFailure>(result),
      );
      final cubit = InvoiceCreateCubit(facade: facade);

      await cubit.initialize();

      expect(cubit.state.result, result);
      verifyNever(() => facade.supportedCurrencies());
      await cubit.close();
    },
  );

  test('double submit is inert after success', () async {
    when(() => facade.create(any())).thenAnswer((_) async => Ok(result));
    final cubit = await initialized();
    cubit.amountChanged('1000');

    await cubit.submit();
    await cubit.submit();

    verify(() => facade.create(any())).called(1);
    await cubit.close();
  });
}
