import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockRecipientsFacade extends Mock implements RecipientsFacade {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

void main() {
  late _MockExchangeOrderRepository mainnetRepository;
  late _MockExchangeOrderRepository testnetRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockRecipientsFacade recipientsFacade;
  late ConfirmWithdrawOrderUsecase usecase;
  late InteracSecurityDetails interacSecurityDetails;

  setUp(() {
    mainnetRepository = _MockExchangeOrderRepository();
    testnetRepository = _MockExchangeOrderRepository();
    settingsRepository = _MockSettingsRepository();
    recipientsFacade = _MockRecipientsFacade();
    usecase = ConfirmWithdrawOrderUsecase(
      mainnetExchangeOrderRepository: mainnetRepository,
      testnetExchangeOrderRepository: testnetRepository,
      settingsRepository: settingsRepository,
      recipientsFacade: recipientsFacade,
    );
    interacSecurityDetails =
        (InteracSecurityDetails.create(
                  recipientId: 'recipient-1',
                  email: 'person@example.com',
                  securityQuestion: 'Favourite city?',
                  securityAnswer: 'Montreal',
                )
                as Ok<InteracSecurityDetails, RecipientsFailure>)
            .value;
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  });

  test('confirms the order before saving Interac defaults', () async {
    final order = _MockWithdrawOrder();
    when(
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
    ).thenAnswer((_) async => order);
    when(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    final result = await usecase.execute(
      orderId: 'order-1',
      interacSecurityDetails: interacSecurityDetails,
      saveSecurityDetailsAsDefault: true,
    );

    expect(result, same(order));
    verifyInOrder([
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    ]);
  });

  test('clears saved Interac defaults when save is not selected', () async {
    final order = _MockWithdrawOrder();
    when(
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
    ).thenAnswer((_) async => order);
    when(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    await usecase.execute(
      orderId: 'order-1',
      interacSecurityDetails: interacSecurityDetails,
    );

    verify(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: null,
        securityAnswer: null,
      ),
    ).called(1);
  });

  test(
    'does not fail a confirmed order when updating defaults fails',
    () async {
      final order = _MockWithdrawOrder();
      when(
        () => mainnetRepository.confirmWithdrawOrder('order-1'),
      ).thenAnswer((_) async => order);
      when(
        () => recipientsFacade.updateInteracSecurityDetails(
          recipientId: any(named: 'recipientId'),
          email: any(named: 'email'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenAnswer(
        (_) async => const Err<void, RecipientsFailure>(
          RecipientsUnexpectedFailure('update failed'),
        ),
      );

      final result = await usecase.execute(
        orderId: 'order-1',
        interacSecurityDetails: interacSecurityDetails,
        saveSecurityDetailsAsDefault: true,
      );

      expect(result, same(order));
    },
  );

  test('does not update recipients for non-Interac withdrawals', () async {
    final order = _MockWithdrawOrder();
    when(
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(orderId: 'order-1');

    expect(result, same(order));
    verifyZeroInteractions(recipientsFacade);
  });

  test('routes testnet confirmation to the testnet repository', () async {
    final order = _MockWithdrawOrder();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => testnetRepository.confirmWithdrawOrder('order-1'),
    ).thenAnswer((_) async => order);

    final result = await usecase.execute(orderId: 'order-1');

    expect(result, same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('sanitizes unexpected confirmation failures', () async {
    when(
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
    ).thenThrow(Exception('Montreal'));

    await expectLater(
      usecase.execute(orderId: 'order-1'),
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
