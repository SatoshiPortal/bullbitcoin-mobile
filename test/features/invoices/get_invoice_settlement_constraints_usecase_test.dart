import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/invoices/domain/usecases/get_invoice_settlement_constraints_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFiatSettlementFacade extends Mock implements FiatSettlementFacade {}

void main() {
  late _MockFiatSettlementFacade facade;
  late GetInvoiceSettlementConstraintsUsecase usecase;

  setUp(() {
    facade = _MockFiatSettlementFacade();
    usecase = GetInvoiceSettlementConstraintsUsecase(facade);
  });

  test('mixed settlement removes the direct Liquid payer rail', () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => const Ok(
        FiatSettlementConfigurationView(
          products: [
            FiatSettlementProductConfig(
              product: FiatSettlementProduct.invoice,
              fiatPercentage: 50,
              currency: FiatCurrency.cad,
            ),
          ],
          credentialActive: true,
        ),
      ),
    );

    final result = await usecase.execute();

    expect(result?.directLiquidAvailable, isFalse);
  });

  test('bitcoin-only and fiat-only settlement keep direct Liquid', () async {
    for (final percentage in [0, 100]) {
      when(() => facade.configuration()).thenAnswer(
        (_) async => Ok(
          FiatSettlementConfigurationView(
            products: [
              FiatSettlementProductConfig(
                product: FiatSettlementProduct.invoice,
                fiatPercentage: percentage,
                currency: percentage == 0 ? null : FiatCurrency.cad,
              ),
            ],
            credentialActive: percentage > 0,
          ),
        ),
      );

      final result = await usecase.execute();

      expect(result?.directLiquidAvailable, isTrue);
    }
  });

  test('configuration failure preserves the caller last-known state', () async {
    when(
      () => facade.configuration(),
    ).thenAnswer((_) async => const Err(FiatSettlementFailure.unexpected()));

    expect(await usecase.execute(), isNull);
  });
}
