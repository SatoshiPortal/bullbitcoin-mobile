import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sell/domain/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockSellOrder extends Mock implements SellOrder {}

class _MockFiatPaymentOrder extends Mock implements FiatPaymentOrder {}

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockPayjoinPolicy payjoinPolicy;
  late CreateSellOrderUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(1));
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    final settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);

    payjoinPolicy = _MockPayjoinPolicy();
    when(payjoinPolicy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );

    usecase = CreateSellOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: _MockExchangeOrderRepository(),
      settingsRepository: settingsRepository,
      payjoinPolicy: payjoinPolicy,
    );
  });

  Future<Result<Order, SellFailure>> run() => usecase.execute(
    orderAmount: const FiatAmount(100),
    currency: FiatCurrency.cad,
    network: OrderBitcoinNetwork.bitcoin,
  );

  void stubThrow(Object error) {
    when(
      () => mainnet.placeSellOrder(
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        usePayjoin: any(named: 'usePayjoin'),
      ),
    ).thenThrow(error);
  }

  group('EUR recipient payouts', () {
    for (final network in OrderBitcoinNetwork.values) {
      for (final type in [
        RecipientType.sepaEur,
        RecipientType.confidentialSepaEur,
      ]) {
        test(
          '${type.name} on ${network.name} keeps the bank order type',
          () async {
            final order = _MockFiatPaymentOrder();
            when(
              payjoinPolicy.load,
            ).thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
            final processor = type == RecipientType.confidentialSepaEur
                ? SepaPaymentProcessor.confidential
                : SepaPaymentProcessor.regular;
            when(
              () => mainnet.placeSellToRecipientOrderV2(
                orderAmount: const FiatAmount(100),
                recipientId: 'own-account',
                network: network,
                paymentProcessor: processor,
                usePayjoin: network == OrderBitcoinNetwork.bitcoin,
              ),
            ).thenAnswer((_) async => order);
            final result = await usecase.execute(
              orderAmount: const FiatAmount(100),
              currency: FiatCurrency.eur,
              network: network,
              recipient: RecipientSelection(
                id: 'own-account',
                type: type,
                isVirtualPayeeActive: true,
              ),
              usePayjoin: true,
            );
            expect(
              result,
              isA<Ok<Order, SellFailure>>().having(
                (r) => r.value,
                'order',
                same(order),
              ),
            );
            verifyNever(
              () => mainnet.placeSellOrder(
                orderAmount: any(named: 'orderAmount'),
                currency: any(named: 'currency'),
                network: any(named: 'network'),
                usePayjoin: any(named: 'usePayjoin'),
              ),
            );
          },
        );
      }
    }

    test(
      'requires confidential recipient activation before creation',
      () async {
        final result = await usecase.execute(
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.eur,
          network: OrderBitcoinNetwork.bitcoin,
          recipient: const RecipientSelection(
            id: 'own-account',
            type: RecipientType.confidentialSepaEur,
          ),
        );
        expect(
          (result as Err<Order, SellFailure>).failure,
          isA<SellConfidentialSepaNotActivatedFailure>(),
        );
        verifyZeroInteractions(mainnet);
      },
    );

    test('rejects recipient payouts outside the EUR SEPA path', () async {
      for (final (currency, type) in [
        (FiatCurrency.cad, RecipientType.sepaEur),
        (FiatCurrency.eur, RecipientType.interacEmailCad),
      ]) {
        final result = await usecase.execute(
          orderAmount: const FiatAmount(100),
          currency: currency,
          network: OrderBitcoinNetwork.bitcoin,
          recipient: RecipientSelection(id: 'recipient', type: type),
        );
        expect(result, isA<Err<Order, SellFailure>>());
      }
      verifyZeroInteractions(mainnet);
    });

    test(
      'an expired recipient activation returns a recoverable failure',
      () async {
        when(
          () => mainnet.placeSellToRecipientOrderV2(
            orderAmount: any(named: 'orderAmount'),
            recipientId: 'own-account',
            network: OrderBitcoinNetwork.bitcoin,
            paymentProcessor: SepaPaymentProcessor.confidential,
          ),
        ).thenThrow(
          const BullBitcoinApiConfidentialSepaNotActivatedException(),
        );
        final result = await usecase.execute(
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.eur,
          network: OrderBitcoinNetwork.bitcoin,
          recipient: const RecipientSelection(
            id: 'own-account',
            type: RecipientType.confidentialSepaEur,
            isVirtualPayeeActive: true,
          ),
        );
        expect(
          (result as Err<Order, SellFailure>).failure,
          isA<SellConfidentialSepaNotActivatedFailure>(),
        );
      },
    );
  });

  group('payjoin follows the sell switch only', () {
    Future<bool> requestedPayjoin(PayjoinPolicy policy) async {
      when(
        payjoinPolicy.load,
      ).thenAnswer((_) async => Ok<PayjoinPolicy, PayjoinFailure>(policy));
      when(
        () => mainnet.placeSellOrder(
          orderAmount: any(named: 'orderAmount'),
          currency: any(named: 'currency'),
          network: any(named: 'network'),
          usePayjoin: any(named: 'usePayjoin'),
        ),
      ).thenAnswer((_) async => _MockSellOrder());

      final _ = await usecase.execute(
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
        usePayjoin: true,
      );

      return verify(
            () => mainnet.placeSellOrder(
              orderAmount: any(named: 'orderAmount'),
              currency: any(named: 'currency'),
              network: any(named: 'network'),
              usePayjoin: captureAny(named: 'usePayjoin'),
            ),
          ).captured.single
          as bool;
    }

    test('on by default, with payments between users off', () async {
      expect(await requestedPayjoin(PayjoinPolicy.defaults()), isTrue);
    });

    test('off when sell is off, even with the user switches on', () async {
      expect(
        await requestedPayjoin(
          PayjoinPolicy.defaults().copyWith(
            sendEnabled: true,
            receiveEnabled: true,
            sellEnabled: false,
          ),
        ),
        isFalse,
      );
    });
  });

  test('returns the placed order', () async {
    final order = _MockSellOrder();
    when(
      () => mainnet.placeSellOrder(
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        usePayjoin: any(named: 'usePayjoin'),
      ),
    ).thenAnswer((_) async => order);

    expect(await run(), isA<Ok<Order, SellFailure>>());
  });

  // These three used to be translated inside the shared exchange repository,
  // which is why SellError lived in core. The mapping now happens here.
  test('maps a below-minimum API rejection with its bound', () async {
    stubThrow(BullBitcoinApiMinAmountException(minAmount: 25, currency: 'CAD'));

    final failure = (await run() as Err<Order, SellFailure>).failure;

    expect(failure, isA<SellBelowMinAmountFailure>());
    expect((failure as SellBelowMinAmountFailure).minAmount, 25);
    expect(failure.currency, 'CAD');
  });

  test('maps an above-maximum API rejection with its bound', () async {
    stubThrow(
      BullBitcoinApiMaxAmountException(maxAmount: 5000, currency: 'CAD'),
    );

    final failure = (await run() as Err<Order, SellFailure>).failure;

    expect(failure, isA<SellAboveMaxAmountFailure>());
    expect((failure as SellAboveMaxAmountFailure).maxAmount, 5000);
  });

  test('maps an unauthenticated API to its own failure', () async {
    stubThrow(ApiKeyException('API key not found or inactive'));

    expect(
      (await run() as Err<Order, SellFailure>).failure,
      isA<SellUnauthenticatedFailure>(),
    );
  });

  test(
    'sanitizes an unexpected error and keeps the reason for logs only',
    () async {
      stubThrow(Exception('Dio 500 apikey=secret123'));

      final failure = (await run() as Err<Order, SellFailure>).failure;

      expect(failure, isA<SellUnexpectedFailure>());
      expect(
        failure.logMessage,
        contains('secret123'),
        reason: 'the reason belongs in the log, not in the user message',
      );
    },
  );
}
