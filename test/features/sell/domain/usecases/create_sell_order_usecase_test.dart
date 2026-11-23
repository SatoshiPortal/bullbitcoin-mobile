import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockSellOrder extends Mock implements SellOrder {}

class _MockFiatPaymentOrder extends Mock implements FiatPaymentOrder {}

void main() {
  var spendStatus = BitcoinSpendStatus.ready;
  late _MockExchangeOrders mainnet;
  late _MockPayjoinPolicy payjoinPolicy;
  late CreateSellOrderUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(1));
    registerFallbackValue(FiatCurrency.cad);
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    spendStatus = BitcoinSpendStatus.ready;
    mainnet = _MockExchangeOrders();
    final settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));

    payjoinPolicy = _MockPayjoinPolicy();
    when(payjoinPolicy.load).thenAnswer(
      (_) async =>
          const Err<PayjoinPolicy, PayjoinFailure>(PayjoinStorageFailure()),
    );

    usecase = CreateSellOrderUsecase(
      wallet: WalletFacade(
        const Stream.empty(),
        spendStatus: (_, {replacing}) async => spendStatus,
      ),
      exchange: exchangeForTesting(
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? _MockExchangeOrders()
            : mainnet,
      ),
      settingsRepository: settingsRepository,
      payjoinPolicy: payjoinPolicy,
    );
  });

  Future<Result<Order, SellFailure>> run() => usecase.execute(
    walletId: 'wallet-1',
    orderAmount: const FiatAmount(100),
    currency: FiatCurrency.cad,
    network: OrderBitcoinNetwork.bitcoin,
  );

  void stubFailure(ExchangeFailure error) {
    when(
      () => mainnet.placeSellOrder(
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        usePayjoin: any(named: 'usePayjoin'),
      ),
    ).thenAnswer((_) async => Err(error));
  }

  test('gated Bitcoin wallet creates no exchange order', () async {
    spendStatus = BitcoinSpendStatus.pending;
    final result = await run();
    expect(
      result,
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<SellSpendBlockedFailure>().having((f) => f.busy, 'busy', isFalse),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(payjoinPolicy);
  });

  test('a busy wallet is not reported as awaiting a payment', () async {
    spendStatus = BitcoinSpendStatus.busy;
    final result = await run();
    expect(
      result,
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<SellSpendBlockedFailure>().having((f) => f.busy, 'busy', isTrue),
      ),
    );
    verifyZeroInteractions(mainnet);
  });

  test('regtest refuses sell creation before backend IO', () async {
    final settings = _MockSettingsRepository();
    final testnet = _MockExchangeOrders();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    final guarded = CreateSellOrderUsecase(
      wallet: WalletFacade(
        const Stream.empty(),
        spendStatus: (_, {replacing}) async => spendStatus,
      ),
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settings,
      payjoinPolicy: payjoinPolicy,
    );
    final result = await guarded.execute(
      walletId: 'wallet-1',
      orderAmount: const FiatAmount(100),
      currency: FiatCurrency.cad,
      network: OrderBitcoinNetwork.bitcoin,
    );
    expect(
      result,
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<SellUnsupportedNetworkFailure>(),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(testnet);
    verifyZeroInteractions(payjoinPolicy);
  });

  group('recipient payouts', () {
    for (final network in OrderBitcoinNetwork.values) {
      for (final type in [
        RecipientType.sepaEur,
        RecipientType.confidentialSepaEur,
      ]) {
        test(
          '${type.name} on ${network.name} keeps the bank order type',
          () async {
            final order = _MockFiatPaymentOrder();
            when(payjoinPolicy.load)
                .thenAnswer((_) async => Ok(PayjoinPolicy.defaults()));
            final processor = type == RecipientType.confidentialSepaEur
                ? SepaPaymentProcessor.confidential
                : SepaPaymentProcessor.regular;
            when(
              () => mainnet.placePayOrder(
                orderAmount: const FiatAmount(100),
                recipientId: 'own-account',
                network: network,
                paymentProcessor: processor,
                usePayjoin: network == OrderBitcoinNetwork.bitcoin,
              ),
            ).thenAnswer((_) async => Ok(order));
            final result = await usecase.execute(
              walletId: 'wallet-1',
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
          walletId: 'wallet-1',
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

    test('sends a non-SEPA recipient without a SEPA processor', () async {
      final order = _MockFiatPaymentOrder();
      when(
        () => mainnet.placePayOrder(
          orderAmount: const FiatAmount(100),
          recipientId: 'interac',
          network: OrderBitcoinNetwork.liquid,
        ),
      ).thenAnswer((_) async => Ok(order));
      final result = await usecase.execute(
        walletId: 'wallet-1',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.liquid,
        recipient: const RecipientSelection(
          id: 'interac',
          type: RecipientType.interacEmailCad,
        ),
      );
      expect(
        result,
        isA<Ok<Order, SellFailure>>().having(
          (r) => r.value,
          'order',
          same(order),
        ),
      );
    });

    test('rejects a recipient in another currency', () async {
      for (final (currency, type) in [
        (FiatCurrency.cad, RecipientType.sepaEur),
        (FiatCurrency.eur, RecipientType.interacEmailCad),
      ]) {
        final result = await usecase.execute(
          walletId: 'wallet-1',
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
          () => mainnet.placePayOrder(
            orderAmount: any(named: 'orderAmount'),
            recipientId: 'own-account',
            network: OrderBitcoinNetwork.bitcoin,
            paymentProcessor: SepaPaymentProcessor.confidential,
          ),
        ).thenAnswer(
          (_) async => const Err(ExchangeConfidentialSepaInactiveFailure()),
        );
        final result = await usecase.execute(
          walletId: 'wallet-1',
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
      when(payjoinPolicy.load)
          .thenAnswer((_) async => Ok<PayjoinPolicy, PayjoinFailure>(policy));
      when(
        () => mainnet.placeSellOrder(
          orderAmount: any(named: 'orderAmount'),
          currency: any(named: 'currency'),
          network: any(named: 'network'),
          usePayjoin: any(named: 'usePayjoin'),
        ),
      ).thenAnswer((_) async => Ok(_MockSellOrder()));

      final _ = await usecase.execute(
        walletId: 'wallet-1',
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

    test('on by default, with receiving for users off', () async {
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
    ).thenAnswer((_) async => Ok(order));

    expect(await run(), isA<Ok<Order, SellFailure>>());
  });

  // These three used to be translated inside the shared exchange repository,
  // which is why SellError lived in core. The mapping now happens here.
  test('maps a below-minimum API rejection with its bound', () async {
    stubFailure(
      const ExchangeOrderLimitFailure(
        ExchangeOrderAmountBound.minimum,
        25,
        'CAD',
      ),
    );

    final failure = (await run() as Err<Order, SellFailure>).failure;

    expect(failure, isA<SellBelowMinAmountFailure>());
    expect((failure as SellBelowMinAmountFailure).minAmount, 25);
    expect(failure.currency, 'CAD');
  });

  test('maps an above-maximum API rejection with its bound', () async {
    stubFailure(
      const ExchangeOrderLimitFailure(
        ExchangeOrderAmountBound.maximum,
        5000,
        'CAD',
      ),
    );

    final failure = (await run() as Err<Order, SellFailure>).failure;

    expect(failure, isA<SellAboveMaxAmountFailure>());
    expect((failure as SellAboveMaxAmountFailure).maxAmount, 5000);
  });

  test('maps an unauthenticated API to its own failure', () async {
    stubFailure(const ExchangeNotAuthenticatedFailure());

    expect(
      (await run() as Err<Order, SellFailure>).failure,
      isA<SellUnauthenticatedFailure>(),
    );
  });

  test('keeps foreign diagnostic text out of an unexpected failure', () async {
    stubFailure(const ExchangeOrderLoadFailure());

    final failure = (await run() as Err<Order, SellFailure>).failure;

    expect(failure, isA<SellUnexpectedFailure>());
    expect(failure.logMessage, isNull);
  });
}
