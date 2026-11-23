import 'package:bull_exchange/testing.dart';
import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _MockLogger extends Mock implements Logger {}

void main() {
  test(
    'an environment change refuses payout before Payjoin or Exchange',
    () async {
      final orders = _MockOrders();
      final settings = _MockSettingsRepository();
      final receiver = _MockPayjoinReceiver();
      final policy = _MockPayjoinPolicyAccess();
      when(settings.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      final usecase = CreateBuyOrderUsecase(
        exchange: exchangeForTesting(orders: (_) => orders),
        settingsRepository: settings,
        payjoinReceiver: receiver,
        payjoinPolicy: policy,
      );
      final result = await usecase.execute(
        toAddress: '1BoatSLRHtKNngkdXEeobR76b53LETtpyT',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: BtcNetwork.bitcoin,
        isOwner: true,
        expectedEnvironment: Environment.mainnet,
      );
      expect(result, isA<Err<BuyOrder, BuyFailure>>());
      verifyZeroInteractions(policy);
      verifyZeroInteractions(receiver);
      verifyZeroInteractions(orders);
    },
  );

  test('regtest refuses creation before backend or payjoin access', () async {
    final mainnet = _MockOrders();
    final testnet = _MockOrders();
    final settings = _MockSettingsRepository();
    final receiver = _MockPayjoinReceiver();
    final policy = _MockPayjoinPolicyAccess();
    when(settings.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    final result =
        await CreateBuyOrderUsecase(
          exchange: exchangeForTesting(
            orders: (environment) =>
                environment == ExchangeEnvironment.testnet ? testnet : mainnet,
          ),
          settingsRepository: settings,
          payjoinReceiver: receiver,
          payjoinPolicy: policy,
        ).execute(
          toAddress: 'bcrt1qexample',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: BtcNetwork.bitcoin,
          isOwner: true,
          payjoinWalletId: 'regtest-wallet',
          payjoinAmountSat: 10000,
        );
    expect(
      result,
      isA<Err<BuyOrder, BuyFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BuyUnsupportedNetworkFailure>(),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(testnet);
    verifyZeroInteractions(receiver);
    verifyZeroInteractions(policy);
  });

  setUpAll(() {
    registerFallbackValue(
      StartPayjoinReceiver(
        walletId: 'fallback',
        network: BitcoinNetwork.testnet,
        address: 'tb1qfallback',
      ),
    );
  });

  for (final stale in [false, true]) {
    test('a refused buy cleans up only a known orphan: stale=$stale', () async {
      const address = 'tb1qexampleaddress';
      const endpoint = 'bitcoin:$address?pj=https://payjoin.example.invalid';
      const sessionId = 'synthetic-session';
      final orders = _MockOrders();
      final settings = _MockSettingsRepository();
      final receiver = _MockPayjoinReceiver();
      final policy = _MockPayjoinPolicyAccess();
      final session = PayjoinReceiverSession(
        status: PayjoinStatus.started,
        id: sessionId,
        network: BitcoinNetwork.testnet,
        walletId: 'wallet-1',
        createdAt: DateTime.utc(2026, 11, 23),
        expiresAt: DateTime.utc(2026, 11, 23, 0, 6),
        payjoinUri: endpoint,
      );
      when(settings.fetch).thenAnswer(
        (_) async => const Ok(
          SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(policy.load).thenAnswer(
        (_) async => Ok(
          PayjoinPolicy(
            sendEnabled: false,
            receiveEnabled: false,
            buyEnabled: true,
            sellEnabled: false,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
          ),
        ),
      );
      when(() => receiver.start(any())).thenAnswer((_) async => Ok(session));
      when(() => receiver.cancel(sessionId))
          .thenAnswer((_) async => const Ok(null));
      when(
        () => orders.placeBuyOrder(
          toAddress: address,
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: BtcNetwork.bitcoin,
          isOwner: true,
          payjoinBip21: endpoint,
        ),
      ).thenAnswer(
        (_) async => stale
            ? const Err(ExchangeOperationStaleFailure())
            : const Err(ExchangeNotAuthenticatedFailure()),
      );

      final result =
          await CreateBuyOrderUsecase(
            exchange: exchangeForTesting(orders: (_) => orders),
            settingsRepository: settings,
            payjoinReceiver: receiver,
            payjoinPolicy: policy,
          ).execute(
            toAddress: address,
            orderAmount: const FiatAmount(100),
            currency: FiatCurrency.cad,
            network: BtcNetwork.bitcoin,
            isOwner: true,
            payjoinWalletId: 'wallet-1',
            payjoinAmountSat: 10000,
          );

      expect(result, isA<Err<BuyOrder, BuyFailure>>());
      verify(
        () => orders.placeBuyOrder(
          toAddress: address,
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: BtcNetwork.bitcoin,
          isOwner: true,
          payjoinBip21: endpoint,
        ),
      ).called(1);
      if (stale) {
        verifyNever(() => receiver.cancel(sessionId));
      } else {
        verify(() => receiver.cancel(sessionId)).called(1);
      }
    });
  }

  // The receiver starts before the exchange's five-minute payout window. It
  // needs a short margin without surviving for the protocol's 24-hour default.
  test(
    'the payjoin payout session expires with the exchange, not in 24h',
    () async {
      final orders = _MockOrders();
      final settings = _MockSettingsRepository();
      final receiver = _MockPayjoinReceiver();
      final policy = _MockPayjoinPolicyAccess();

      when(() => settings.fetch()).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      when(() => policy.load()).thenAnswer(
        (_) async => Ok(
          PayjoinPolicy(
            sendEnabled: false,
            receiveEnabled: false,
            buyEnabled: true,
            sellEnabled: false,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
          ),
        ),
      );
      when(
        () => orders.placeBuyOrder(
          toAddress: 'tb1qexampleaddress',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: BtcNetwork.bitcoin,
          isOwner: true,
          payjoinBip21: null,
        ),
      ).thenAnswer((_) async => Ok(_MockBuyOrder()));

      StartPayjoinReceiver? captured;
      when(() => receiver.start(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as StartPayjoinReceiver;
        throw StateError('stop here: the expiry is what this test is about');
      });

      final usecase = CreateBuyOrderUsecase(
        exchange: exchangeForTesting(orders: (_) => orders),
        settingsRepository: settings,
        payjoinReceiver: receiver,
        payjoinPolicy: policy,
      );

      final before = DateTime.now();
      final result = await usecase.execute(
        toAddress: 'tb1qexampleaddress',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: BtcNetwork.bitcoin,
        isOwner: true,
        payjoinWalletId: 'wallet-1',
        payjoinAmountSat: 10000,
      );
      final after = DateTime.now();

      expect(result, isA<Ok<BuyOrder, BuyFailure>>());

      final expiresAt = captured?.expiresAt;
      expect(expiresAt, isNotNull, reason: 'a payjoin session must be started');
      // Started under the buy switch while receiving from users is off: the
      // session must stay gated by buy, not by receive.
      expect(captured!.isTrade, isTrue);

      // Bracketed against the wall clock either side of the call: the use case
      // computes its own `now` somewhere between `before` and `after`, so the
      // deadline must land in [before + 6m, after + 6m]. Tight enough that 24h
      // fails, loose enough that a slow machine does not.
      expect(
        expiresAt!.isBefore(before.add(const Duration(minutes: 6))),
        isFalse,
      );
      expect(expiresAt.isAfter(after.add(const Duration(minutes: 6))), isFalse);
    },
  );
  test('a payjoin fallback log never carries the foreign cause text', () async {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    final orders = _MockOrders();
    final settings = _MockSettingsRepository();
    final receiver = _MockPayjoinReceiver();
    final policy = _MockPayjoinPolicyAccess();

    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(() => policy.load()).thenAnswer(
      (_) async => Ok(
        PayjoinPolicy(
          sendEnabled: false,
          receiveEnabled: false,
          buyEnabled: true,
          sellEnabled: false,
          minimumAmount: PayjoinPolicy.minimumAllowedAmount,
          sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
        ),
      ),
    );
    when(
      () => orders.placeBuyOrder(
        toAddress: 'tb1qexampleaddress',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: BtcNetwork.bitcoin,
        isOwner: true,
        payjoinBip21: null,
      ),
    ).thenAnswer((_) async => Ok(_MockBuyOrder()));
    // Foreign exception text can quote the payment request it failed on.
    when(() => receiver.start(any())).thenThrow(
      StateError('bitcoin:tb1qexampleaddress?pj=https://private-directory'),
    );

    final result =
        await CreateBuyOrderUsecase(
          exchange: exchangeForTesting(orders: (_) => orders),
          settingsRepository: settings,
          payjoinReceiver: receiver,
          payjoinPolicy: policy,
        ).execute(
          toAddress: 'tb1qexampleaddress',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: BtcNetwork.bitcoin,
          isOwner: true,
          payjoinWalletId: 'wallet-1',
          payjoinAmountSat: 10000,
        );

    expect(result, isA<Ok<BuyOrder, BuyFailure>>());
    final logged = verify(
      () => logger.warning(
        captureAny(),
        error: captureAny(named: 'error'),
        trace: captureAny(named: 'trace'),
      ),
    ).captured.join(' ');
    expect(logged, contains('StateError'));
    expect(logged, isNot(contains('tb1qexampleaddress')));
    expect(logged, isNot(contains('private-directory')));
  });
}
