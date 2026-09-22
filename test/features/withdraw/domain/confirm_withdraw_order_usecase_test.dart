import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
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

  ConfirmWithdrawOrderUsecase usecase() => ConfirmWithdrawOrderUsecase(
    mainnetExchangeOrderRepository: mainnet,
    testnetExchangeOrderRepository: testnet,
    settingsRepository: settings,
  );

  setUp(() {
    mainnet = _MockExchangeOrderRepository();
    testnet = _MockExchangeOrderRepository();
    settings = _MockSettingsRepository();
  });

  for (final environment in [Environment.mainnet, Environment.testnet]) {
    test('confirms with the $environment repository', () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'EUR',
        ),
      );
      final expectedRepository = environment == Environment.testnet
          ? testnet
          : mainnet;
      when(
        () => expectedRepository.confirmWithdrawOrder('order-1'),
      ).thenAnswer((_) async => _MockWithdrawOrder());

      final result = await usecase().execute(orderId: 'order-1');

      expect(result, isA<Ok<WithdrawOrder, WithdrawFailure>>());
      verify(
        () => expectedRepository.confirmWithdrawOrder('order-1'),
      ).called(1);
    });
  }

  test('maps a known repository error', () async {
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'EUR',
      ),
    );
    when(
      () => mainnet.confirmWithdrawOrder('order-1'),
    ).thenThrow(const WithdrawError.orderAlreadyConfirmed());

    final result = await usecase().execute(orderId: 'order-1');

    expect(result, isA<Err<WithdrawOrder, WithdrawFailure>>());
    expect(
      (result as Err<WithdrawOrder, WithdrawFailure>).failure,
      isA<WithdrawOrderAlreadyConfirmedFailure>(),
    );
  });

  test(
    'maps an unexpected exception without catching programming errors',
    () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'EUR',
        ),
      );
      when(
        () => mainnet.confirmWithdrawOrder('order-1'),
      ).thenThrow(Exception('offline'));

      final result = await usecase().execute(orderId: 'order-1');

      expect(result, isA<Err<WithdrawOrder, WithdrawFailure>>());
      expect(
        (result as Err<WithdrawOrder, WithdrawFailure>).failure,
        isA<WithdrawUnexpectedFailure>(),
      );
    },
  );
}
