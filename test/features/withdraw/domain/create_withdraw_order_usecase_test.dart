import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockExchangeOrderRepository testnet;
  late _MockSettingsRepository settings;
  late CreateWithdrawOrderUsecase usecase;

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settings = _MockSettingsRepository();
    usecase = CreateWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settings,
    );
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'EUR',
      ),
    );
  });

  test('maps confidential SEPA to the confidential processor', () async {
    when(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.confidential,
        isETransfer: false,
      ),
    ).thenAnswer((_) async => _MockWithdrawOrder());

    final result = await usecase.execute(
      fiatAmount: 100,
      recipientId: 'recipient-1',
      recipientType: RecipientType.confidentialSepaEur,
    );

    expect(result, isA<Ok<WithdrawOrder, WithdrawFailure>>());
    verify(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.confidential,
        isETransfer: false,
      ),
    ).called(1);
  });

  test('maps Interac to e-transfer without a SEPA processor', () async {
    when(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        isETransfer: true,
      ),
    ).thenAnswer((_) async => _MockWithdrawOrder());

    await usecase.execute(
      fiatAmount: 100,
      recipientId: 'recipient-1',
      recipientType: RecipientType.interacEmailCad,
    );

    verify(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        isETransfer: true,
      ),
    ).called(1);
  });

  test('forwards the payment description', () async {
    when(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.regular,
        paymentDescription: 'invoice 42',
        isETransfer: false,
      ),
    ).thenAnswer((_) async => _MockWithdrawOrder());

    final result = await usecase.execute(
      fiatAmount: 100,
      recipientId: 'recipient-1',
      recipientType: RecipientType.sepaEur,
      paymentDescription: 'invoice 42',
    );

    expect(result, isA<Ok<WithdrawOrder, WithdrawFailure>>());
    verify(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.regular,
        paymentDescription: 'invoice 42',
        isETransfer: false,
      ),
    ).called(1);
  });

  test('maps an unauthenticated repository error', () async {
    when(
      () => mainnet.placeWithdrawalOrder(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        paymentProcessor: SepaPaymentProcessor.regular,
        isETransfer: false,
      ),
    ).thenThrow(const WithdrawError.unauthenticated());

    final result = await usecase.execute(
      fiatAmount: 100,
      recipientId: 'recipient-1',
      recipientType: RecipientType.sepaEur,
    );

    expect(result, isA<Err<WithdrawOrder, WithdrawFailure>>());
    expect(
      (result as Err<WithdrawOrder, WithdrawFailure>).failure,
      isA<WithdrawUnauthenticatedFailure>(),
    );
  });
}
