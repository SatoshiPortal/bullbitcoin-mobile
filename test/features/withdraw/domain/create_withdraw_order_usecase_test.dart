import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

void main() {
  late _MockExchangeOrderRepository mainnetRepository;
  late _MockExchangeOrderRepository testnetRepository;
  late _MockSettingsRepository settingsRepository;
  late CreateWithdrawOrderUsecase usecase;

  setUp(() {
    mainnetRepository = _MockExchangeOrderRepository();
    testnetRepository = _MockExchangeOrderRepository();
    settingsRepository = _MockSettingsRepository();
    usecase = CreateWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnetRepository,
      testnetExchangeOrderRepository: testnetRepository,
      settingsRepository: settingsRepository,
    );
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  });

  test('validates and submits trimmed Interac security details', () async {
    final order = _MockWithdrawOrder();
    when(
      () => mainnetRepository.placeWithdrawalOrder(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(
      fiatAmount: 125,
      recipientId: 'recipient-1',
      recipientEmail: 'person@example.com',
      securityQuestion: '  Favourite city?  ',
      securityAnswer: '  Montreal  ',
    );

    expect(result.order, same(order));
    expect(result.interacSecurityDetails?.securityQuestion, 'Favourite city?');
    expect(result.interacSecurityDetails?.securityAnswer, 'Montreal');
    verify(
      () => mainnetRepository.placeWithdrawalOrder(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    ).called(1);
  });

  test('keeps non-Interac withdrawal payload unchanged', () async {
    final order = _MockWithdrawOrder();
    when(
      () => mainnetRepository.placeWithdrawalOrder(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(
      fiatAmount: 125,
      recipientId: 'recipient-1',
    );

    expect(result.order, same(order));
    expect(result.interacSecurityDetails, isNull);
    verify(
      () => mainnetRepository.placeWithdrawalOrder(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        securityQuestion: null,
        securityAnswer: null,
      ),
    ).called(1);
  });

  test(
    'rejects incomplete Interac security details before the API call',
    () async {
      await expectLater(
        usecase.execute(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          recipientEmail: 'person@example.com',
          securityQuestion: 'Favourite city?',
        ),
        throwsA(isA<UnexpectedWithdrawError>()),
      );

      verifyZeroInteractions(mainnetRepository);
      verifyZeroInteractions(testnetRepository);
    },
  );

  test(
    'rejects invalid Interac security details before the API call',
    () async {
      await expectLater(
        usecase.execute(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          recipientEmail: 'person@example.com',
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal!',
        ),
        throwsA(isA<UnexpectedWithdrawError>()),
      );

      verifyZeroInteractions(mainnetRepository);
      verifyZeroInteractions(testnetRepository);
    },
  );

  test('routes testnet orders to the testnet repository', () async {
    final order = _MockWithdrawOrder();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => testnetRepository.placeWithdrawalOrder(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(
      fiatAmount: 125,
      recipientId: 'recipient-1',
    );

    expect(result.order, same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('sanitizes unexpected failures', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('Montreal'));

    await expectLater(
      usecase.execute(fiatAmount: 125, recipientId: 'recipient-1'),
      throwsA(
        isA<UnexpectedWithdrawError>().having(
          (error) => error.message,
          'message',
          isNot(contains('Montreal')),
        ),
      ),
    );
  });
}
