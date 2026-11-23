import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockExchangeRecipients extends Mock implements ExchangeRecipients {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

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
  late _MockExchangeOrders mainnetRepository;
  late _MockExchangeOrders testnetRepository;
  late _MockSettingsRepository settingsRepository;
  late _MockExchangeRecipients recipientsFacade;
  late ConfirmWithdrawOrderUsecase usecase;
  late InteracSecurityDetails interacSecurityDetails;

  setUp(() {
    mainnetRepository = _MockExchangeOrders();
    testnetRepository = _MockExchangeOrders();
    settingsRepository = _MockSettingsRepository();
    recipientsFacade = _MockExchangeRecipients();
    usecase = ConfirmWithdrawOrderUsecase(
      exchange: exchangeForTesting(
        recipients: recipientsFacade,
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? testnetRepository
            : mainnetRepository,
      ),
      settingsRepository: settingsRepository,
    );
    interacSecurityDetails = _ok(
      InteracSecurityDetails.create(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    );
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
  });

  test(
    'regtest refuses confirmation before backend or recipient access',
    () async {
      when(settingsRepository.fetch).thenAnswer(
        (_) async => Ok(
          const SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        ),
      );
      final result = await usecase.execute(
        orderId: 'order-1',
        interacSecurityDetails: interacSecurityDetails,
        saveSecurityDetailsAsDefault: true,
      );
      expect(_err(result), isA<WithdrawUnsupportedNetworkFailure>());
      verifyZeroInteractions(mainnetRepository);
      verifyZeroInteractions(testnetRepository);
      verifyZeroInteractions(recipientsFacade);
    },
  );

  test('confirms the order before saving Interac defaults', () async {
    final order = _MockWithdrawOrder();
    when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => Ok(order));
    when(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    final result = await usecase.execute(
      orderId: 'order-1',
      interacSecurityDetails: interacSecurityDetails,
      saveSecurityDetailsAsDefault: true,
    );

    expect(_ok(result), same(order));
    verifyInOrder([
      () => mainnetRepository.confirmWithdrawOrder('order-1'),
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
        isTestnet: false,
      ),
    ]);
  });

  test('clears saved Interac defaults when save is not selected', () async {
    final order = _MockWithdrawOrder();
    when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => Ok(order));
    when(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: any(named: 'recipientId'),
        email: any(named: 'email'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    final result = await usecase.execute(
      orderId: 'order-1',
      interacSecurityDetails: interacSecurityDetails,
    );

    expect(_ok(result), same(order));

    verify(
      () => recipientsFacade.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: null,
        securityAnswer: null,
        isTestnet: false,
      ),
    ).called(1);
  });

  test(
    'does not fail a confirmed order when updating defaults fails',
    () async {
      final order = _MockWithdrawOrder();
      when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
          .thenAnswer((_) async => Ok(order));
      when(
        () => recipientsFacade.updateInteracSecurityDetails(
          recipientId: any(named: 'recipientId'),
          email: any(named: 'email'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
          isTestnet: any(named: 'isTestnet'),
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

      expect(_ok(result), same(order));
    },
  );

  test('does not update recipients for non-Interac withdrawals', () async {
    final order = _MockWithdrawOrder();
    when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => Ok(order));

    final result = await usecase.execute(orderId: 'order-1');

    expect(_ok(result), same(order));
    verifyZeroInteractions(recipientsFacade);
  });

  test('routes testnet confirmation to the testnet repository', () async {
    final order = _MockWithdrawOrder();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    when(() => testnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => Ok(order));

    final result = await usecase.execute(orderId: 'order-1');

    expect(_ok(result), same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('sanitizes unexpected confirmation failures', () async {
    when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => const Err(ExchangeOrderLoadFailure()));

    final result = await usecase.execute(orderId: 'order-1');

    expect(
      _err(result),
      isA<WithdrawUnexpectedFailure>().having(
        (failure) => failure.logMessage,
        'logMessage',
        isNot(contains('Montreal')),
      ),
    );
  });
}
