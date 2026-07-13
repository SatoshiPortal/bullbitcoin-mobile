import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

void main() {
  final result = CreateInvoiceResult(
    invoiceId: InvoiceId('inv-1'),
    shareUrl: InvoiceUrl('https://bullpay.ca/invoice/inv-1'),
  );

  setUpAll(() {
    registerFallbackValue(
      CreateInvoiceCommand(
        amountSat: 1,
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
        expiresAt: DateTime.utc(2030),
      ),
    );
  });

  late _MockFacade facade;

  setUp(() {
    facade = _MockFacade();
    when(() => facade.supportedCurrencies()).thenAnswer(
      (_) async => const BullnymSupportedCurrencies(
        currencies: [
          BullnymSupportedCurrency(code: 'CAD', precision: 2),
          BullnymSupportedCurrency(code: 'COP', precision: 0),
        ],
      ),
    );
  });

  test(
    'sats submit builds an amountSat command and exposes the share URL',
    () async {
      when(() => facade.create(any())).thenAnswer((_) async => Ok(result));

      final cubit = InvoiceCreateCubit(facade: facade);
      cubit.amountModeChanged(InvoiceAmountMode.sats);
      cubit.amountChanged('25000');
      cubit.acceptLiquidChanged(true);
      await cubit.submit();

      expect(cubit.state.isSubmitted, isTrue);
      expect(
        cubit.state.result?.shareUrl.value,
        'https://bullpay.ca/invoice/inv-1',
      );
      final sent =
          verify(() => facade.create(captureAny())).captured.single
              as CreateInvoiceCommand;
      expect(sent.amountSat, 25000);
      expect(sent.fiatAmountMinor, isNull);
      expect(sent.linkToPageNym, isNull); // unlinked v1
      await cubit.close();
    },
  );

  test(
    'fiat submit converts to minor units by the currency precision',
    () async {
      when(() => facade.create(any())).thenAnswer((_) async => Ok(result));

      final cubit = InvoiceCreateCubit(facade: facade);
      await cubit.loadCurrencies();
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
    },
  );

  test('no rail selected is refused locally with zero wire calls', () async {
    final cubit = InvoiceCreateCubit(facade: facade);
    cubit.amountChanged('1000');
    cubit.acceptBtcChanged(false);
    cubit.acceptLnChanged(false);
    cubit.acceptLiquidChanged(false);
    await cubit.submit();

    expect(cubit.state.failure?.kind, InvoicesFailureKind.invalidInput);
    verifyNever(() => facade.create(any()));
    await cubit.close();
  });

  test(
    'a facade failure surfaces without leaving the submitting state',
    () async {
      when(() => facade.create(any())).thenAnswer(
        (_) async => const Err(InvoicesFailure.noDefaultLiquidWallet()),
      );

      final cubit = InvoiceCreateCubit(facade: facade);
      cubit.amountChanged('1000');
      cubit.acceptLiquidChanged(true);
      await cubit.submit();

      expect(cubit.state.submitting, isFalse);
      expect(
        cubit.state.failure?.kind,
        InvoicesFailureKind.noDefaultLiquidWallet,
      );
      expect(cubit.state.isSubmitted, isFalse);
      await cubit.close();
    },
  );

  test(
    'double-submit is inert: the second submit does not re-hit the facade',
    () async {
      var calls = 0;
      when(() => facade.create(any())).thenAnswer((_) async {
        calls++;
        return Ok(result);
      });

      final cubit = InvoiceCreateCubit(facade: facade);
      cubit.amountChanged('1000');
      cubit.acceptLiquidChanged(true);
      await cubit.submit();
      await cubit.submit(); // already submitted → inert

      expect(calls, 1);
      await cubit.close();
    },
  );
}
