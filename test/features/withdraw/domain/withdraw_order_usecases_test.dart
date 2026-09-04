import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
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

    Future<Result<WithdrawOrder, WithdrawFailure>> execute() => build().execute(
      fiatAmount: 100,
      recipientId: 'recipient-1',
      recipientType: RecipientType.interacEmailCad,
    );

    test('returns the placed order', () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          isETransfer: true,
        ),
      ).thenAnswer((_) async => order);

      expect(
        (await execute() as Ok<WithdrawOrder, WithdrawFailure>).value,
        order,
      );
    });

    test('flags an e-transfer only for an Interac recipient', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          isETransfer: false,
        ),
      ).thenAnswer((_) async => _MockWithdrawOrder());

      final result = await build().execute(
        fiatAmount: 100,
        recipientId: 'recipient-1',
        recipientType: RecipientType.billPaymentCad,
      );

      expect(result, isA<Ok<WithdrawOrder, WithdrawFailure>>());
    });

    test('sanitizes a failure, keeping the reason for logs only', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          isETransfer: any(named: 'isETransfer'),
        ),
      ).thenThrow(Exception(_rawReason));

      switch (await execute()) {
        case Ok():
          fail('a failed placement must not report an order');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
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
            isETransfer: any(named: 'isETransfer'),
          ),
        ).thenThrow(exception);

        expect(
          (await execute() as Err<WithdrawOrder, WithdrawFailure>).failure,
          isA<WithdrawUnauthenticatedFailure>(),
        );
      }
    });

    test('carries the bound of an out-of-range amount', () async {
      when(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          isETransfer: any(named: 'isETransfer'),
        ),
      ).thenThrow(
        BullBitcoinApiMinAmountException(minAmount: 25, currency: 'CAD'),
      );

      final belowFailure =
          (await execute() as Err<WithdrawOrder, WithdrawFailure>).failure;
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
          isETransfer: any(named: 'isETransfer'),
        ),
      ).thenThrow(
        BullBitcoinApiMaxAmountException(maxAmount: 5000, currency: 'CAD'),
      );

      final aboveFailure =
          (await execute() as Err<WithdrawOrder, WithdrawFailure>).failure;
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
          isETransfer: any(named: 'isETransfer'),
        ),
      ).thenAnswer((_) async => _MockWithdrawOrder());

      expect(await execute(), isA<Ok<WithdrawOrder, WithdrawFailure>>());
      verifyNever(
        () => mainnet.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          isETransfer: any(named: 'isETransfer'),
        ),
      );
    });
  });

  group('ConfirmWithdrawOrderUsecase', () {
    ConfirmWithdrawOrderUsecase build() => ConfirmWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnet,
      testnetExchangeOrderRepository: testnet,
      settingsRepository: settingsRepository,
    );

    test('returns the confirmed order', () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnet.confirmWithdrawOrder('order-1'),
      ).thenAnswer((_) async => order);

      final result = await build().execute(orderId: 'order-1');

      expect((result as Ok<WithdrawOrder, WithdrawFailure>).value, order);
    });

    test('sanitizes a failure, keeping the reason for logs only', () async {
      when(
        () => mainnet.confirmWithdrawOrder('order-1'),
      ).thenThrow(Exception(_rawReason));

      switch (await build().execute(orderId: 'order-1')) {
        case Ok():
          fail('a failed confirmation must not report a confirmed order');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
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

        expect(
          (result as Err<WithdrawOrder, WithdrawFailure>).failure,
          isA<WithdrawUnauthenticatedFailure>(),
        );
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

      expect(
        (await build().userSummary() as Ok<UserSummary, WithdrawFailure>).value,
        _userSummary,
      );
    });

    test('sanitizes the still-throwing core use-case', () async {
      when(
        getUserSummary.execute,
      ).thenThrow(GetExchangeUserSummaryException(_rawReason));

      switch (await build().userSummary()) {
        case Ok():
          fail('a failed load must not report a user summary');
        case Err(:final failure):
          expect(failure, isA<WithdrawUnexpectedFailure>());
          expect(failure.logMessage, contains('secret123'));
      }
    });
  });
}
