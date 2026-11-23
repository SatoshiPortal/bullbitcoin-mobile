import 'package:exchange/testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockExchangeRecipients extends Mock implements ExchangeRecipients {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

const _userSummary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED'],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

/// A reason of the shape the exchange API produces, quoting a key.
const _rawReason = 'DioException 500 apikey=secret123';

/// The value of an [Ok], failing the test on an [Err].
T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

/// The failure of an [Err], failing the test on an [Ok].
F _err<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => fail('expected Err, got $value'),
  Err(:final failure) => failure,
};

class _Logger extends Mock implements Logger {}

void main() {
  late Logger previousLogger;
  late _Logger logger;
  setUpAll(() => registerFallbackValue(StackTrace.empty));
  setUp(() {
    previousLogger = log;
    logger = _Logger();
    log = logger;
  });
  tearDown(() => log = previousLogger);
  late _MockExchangeOrders mainnet;
  late _MockExchangeOrders testnet;
  late _MockSettingsRepository settingsRepository;

  setUp(() {
    mainnet = _MockExchangeOrders();
    testnet = _MockExchangeOrders();
    settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));
  });

  group('CreateWithdrawOrderUsecase', () {
    CreateWithdrawOrderUsecase build() => CreateWithdrawOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
    );

    Future<Result<CreateWithdrawOrderResult, WithdrawFailure>> execute() =>
        build().execute(fiatAmount: 100, recipientId: 'recipient-1');

    test('returns the placed order', () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
        ),
      ).thenAnswer((_) async => Ok(order));

      expect(_ok(await execute()).order, order);
    });

    test('sanitizes a failure, keeping the raw reason out of logs', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

      switch (await execute()) {
        case Ok():
          fail('a failed placement must not report an order');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          // The request can carry the Interac security answer, so the raw
          // reason is kept out of the failure entirely.
          expect(failure.logMessage, isNot(contains('secret123')));
      }
    });

    test('maps a missing or inactive API key to unauthenticated', () async {
      {
        when(
          () => mainnet.placeWithdrawalOrder(
            fiatAmount: any(named: 'fiatAmount'),
            recipientId: any(named: 'recipientId'),
            securityQuestion: any(named: 'securityQuestion'),
            securityAnswer: any(named: 'securityAnswer'),
          ),
        ).thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

        expect(_err(await execute()), isA<WithdrawUnauthenticatedFailure>());
        verifyNever(
          () => logger.severe(
            message: any(named: 'message'),
            error: any(named: 'error'),
            trace: any(named: 'trace'),
          ),
        );
      }
    });

    test('carries the bound of an out-of-range amount', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          ExchangeOrderLimitFailure(
            ExchangeOrderAmountBound.minimum,
            25,
            'CAD',
          ),
        ),
      );

      final belowFailure = _err(await execute());
      expect(
        belowFailure,
        isA<WithdrawBelowMinAmountFailure>()
            .having((f) => f.minAmount, 'minAmount', 25)
            .having((f) => f.currency, 'currency', 'CAD'),
      );

      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer(
        (_) async => const Err(
          ExchangeOrderLimitFailure(
            ExchangeOrderAmountBound.maximum,
            5000,
            'CAD',
          ),
        ),
      );

      final aboveFailure = _err(await execute());
      expect(
        aboveFailure,
        isA<WithdrawAboveMaxAmountFailure>()
            .having((f) => f.maxAmount, 'maxAmount', 5000)
            .having((f) => f.currency, 'currency', 'CAD'),
      );
    });

    test('uses the testnet repository on testnet', () async {
      final settings = _MockSettings();
      when(() => settings.environment).thenReturn(Environment.testnet);
      when(settingsRepository.fetch).thenAnswer((_) async => Ok(settings));
      when(
        () => testnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer((_) async => Ok(_MockWithdrawOrder()));

      expect(
        await execute(),
        isA<Ok<CreateWithdrawOrderResult, WithdrawFailure>>(),
      );
      verifyNever(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      );
    });
  });

  group('ConfirmWithdrawOrderUsecase', () {
    ConfirmWithdrawOrderUsecase build() => ConfirmWithdrawOrderUsecase(
      exchange: exchangeForTesting(
        recipients: _MockExchangeRecipients(),
        orders: (environment) =>
            environment == ExchangeEnvironment.testnet ? testnet : mainnet,
      ),
      settingsRepository: settingsRepository,
    );

    test('returns the confirmed order', () async {
      final order = _MockWithdrawOrder();
      when(() => mainnet.confirmWithdrawOrder('order-1'))
          .thenAnswer((_) async => WriteDone(order));

      final result = await build().execute(orderId: 'order-1');

      expect(_ok(result), order);
    });

    test('sanitizes a refusal, keeping the raw reason out of logs', () async {
      when(() => mainnet.confirmWithdrawOrder('order-1')).thenAnswer(
        (_) async => const WriteRefused(ExchangeRefusal(rpcCode: -32603)),
      );

      switch (await build().execute(orderId: 'order-1')) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, isNot(contains('secret123')));
      }
    });

    test('maps a missing or inactive API key to unauthenticated', () async {
      {
        when(() => mainnet.confirmWithdrawOrder('order-1')).thenAnswer(
          (_) async => const WriteNotSent(ExchangeNotSentReason.signedOut),
        );

        final result = await build().execute(orderId: 'order-1');

        expect(_err(result), isA<WithdrawUnauthenticatedFailure>());
        verifyNever(
          () => logger.severe(
            message: any(named: 'message'),
            error: any(named: 'error'),
            trace: any(named: 'trace'),
          ),
        );
      }
    });
  });

  group('LoadWithdrawContextUsecase', () {
    LoadWithdrawContextUsecase build(
      Result<UserSummary, ExchangeFailure> scenario,
    ) => LoadWithdrawContextUsecase(
      exchangeForTesting(getUserSummary: (_) async => scenario),
    );

    test('returns the user summary', () async {
      expect(_ok(await build(const Ok(_userSummary)).execute()), _userSummary);
    });

    test('does not forward account failure detail', () async {
      switch (await build(const Err(ExchangeUnexpectedFailure(_rawReason)))
          .execute()) {
        case Ok():
          fail('a failed load must not report a user summary');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, isNot(contains(_rawReason)));
      }
    });
  });
}
