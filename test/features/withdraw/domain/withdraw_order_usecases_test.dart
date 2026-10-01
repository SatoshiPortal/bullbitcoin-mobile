import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockRecipientsFacade extends Mock implements RecipientsFacade {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

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

void main() {
  late _MockExchangeOrderRepository mainnet;
  late _MockExchangeOrderRepository testnet;
  late _MockSettingsRepository settingsRepository;

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settingsRepository = _MockSettingsRepository();
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
  });

  group('CreateWithdrawOrderUsecase', () {
    CreateWithdrawOrderUsecase build() => CreateWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
    );

    Future<Result<CreateWithdrawOrderResult, WithdrawFailure>> execute() =>
        build().execute(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          recipientType: RecipientType.bankTransferCad,
        );

    test('returns the placed order', () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          paymentProcessor: null,
          paymentDescription: null,
          securityQuestion: null,
          securityAnswer: null,
        ),
      ).thenAnswer((_) async => order);

      expect(_ok(await execute()).order, order);
    });

    test('sanitizes a failure, keeping the raw reason out of logs', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenThrow(Exception(_rawReason));

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
      for (final exception in [
        ApiKeyNotFoundException(),
        ApiKeyInactiveException(),
      ]) {
        when(
          () => mainnet.placeWithdrawalOrder(
            fiatAmount: any(named: 'fiatAmount'),
            recipientId: any(named: 'recipientId'),
            securityQuestion: any(named: 'securityQuestion'),
            securityAnswer: any(named: 'securityAnswer'),
          ),
        ).thenThrow(exception);

        expect(_err(await execute()), isA<WithdrawUnauthenticatedFailure>());
      }
    });

    test('carries the bound of an out-of-range amount', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenThrow(
        BullBitcoinApiMinAmountException(minAmount: 25, currency: 'CAD'),
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
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenThrow(
        BullBitcoinApiMaxAmountException(maxAmount: 5000, currency: 'CAD'),
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
      when(settingsRepository.fetch).thenAnswer((_) async => settings);
      when(
        () => testnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer((_) async => _MockWithdrawOrder());

      expect(
        await execute(),
        isA<Ok<CreateWithdrawOrderResult, WithdrawFailure>>(),
      );
      verifyNever(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      );
    });
  });

  group('ConfirmWithdrawOrderUsecase', () {
    ConfirmWithdrawOrderUsecase build() => ConfirmWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
      recipientsFacade: _MockRecipientsFacade(),
    );

    test('returns the confirmed order', () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnet.confirmWithdrawOrder('order-1'),
      ).thenAnswer((_) async => order);

      final result = await build().execute(orderId: 'order-1');

      expect(_ok(result), order);
    });

    test('sanitizes a failure, keeping the raw reason out of logs', () async {
      when(
        () => mainnet.confirmWithdrawOrder('order-1'),
      ).thenThrow(Exception(_rawReason));

      switch (await build().execute(orderId: 'order-1')) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, isNot(contains('secret123')));
      }
    });

    test('maps a missing or inactive API key to unauthenticated', () async {
      for (final exception in [
        ApiKeyNotFoundException(),
        ApiKeyInactiveException(),
      ]) {
        when(
          () => mainnet.confirmWithdrawOrder('order-1'),
        ).thenThrow(exception);

        final result = await build().execute(orderId: 'order-1');

        expect(_err(result), isA<WithdrawUnauthenticatedFailure>());
      }
    });
  });

  group('LoadWithdrawContextUsecase', () {
    late _MockGetExchangeUserSummaryUsecase getUserSummary;

    LoadWithdrawContextUsecase build() => LoadWithdrawContextUsecase(
      getExchangeUserSummaryUsecase: getUserSummary,
    );

    setUp(() => getUserSummary = _MockGetExchangeUserSummaryUsecase());

    test('returns the user summary', () async {
      when(getUserSummary.execute).thenAnswer((_) async => _userSummary);

      expect(_ok(await build().execute()), _userSummary);
    });

    test('sanitizes the still-throwing core use-case', () async {
      when(
        getUserSummary.execute,
      ).thenThrow(GetExchangeUserSummaryException(_rawReason));

      switch (await build().execute()) {
        case Ok():
          fail('a failed load must not report a user summary');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
      }
    });
  });
}
