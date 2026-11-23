import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_failure.dart';
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
  late _MockExchangeRecipients recipients;
  late ConfirmWithdrawOrderUsecase usecase;
  late InteracSecurityDetails interacSecurityDetails;

  setUp(() {
    mainnetRepository = _MockExchangeOrders();
    testnetRepository = _MockExchangeOrders();
    settingsRepository = _MockSettingsRepository();
    recipients = _MockExchangeRecipients();
    usecase = ConfirmWithdrawOrderUsecase(
      exchange: exchangeForTesting(
        recipients: recipients,
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
      verifyZeroInteractions(recipients);
    },
  );

  for (final saveDefaults in [true, false]) {
    test(
      'confirms with the selected Interac defaults (save: $saveDefaults)',
      () async {
        final order = _MockWithdrawOrder();
        Future<ExchangeWrite<WithdrawOrder>> confirm() =>
            mainnetRepository.confirmWithdrawOrder(
              'order-1',
              interacUpdate: (
                recipientId: 'recipient-1',
                email: 'person@example.com',
                securityQuestion: saveDefaults ? 'Favourite city?' : null,
                securityAnswer: saveDefaults ? 'Montreal' : null,
              ),
            );
        when(confirm).thenAnswer((_) async => WriteDone(order));

        final result = await usecase.execute(
          orderId: 'order-1',
          interacSecurityDetails: interacSecurityDetails,
          saveSecurityDetailsAsDefault: saveDefaults,
        );

        expect(_ok(result), same(order));
        verify(confirm).called(1);
      },
    );
  }

  test('does not update recipients for non-Interac withdrawals', () async {
    final order = _MockWithdrawOrder();
    when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
        .thenAnswer((_) async => WriteDone(order));

    final result = await usecase.execute(orderId: 'order-1');

    expect(_ok(result), same(order));
    verify(() => mainnetRepository.confirmWithdrawOrder('order-1')).called(1);
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
        .thenAnswer((_) async => WriteDone(order));

    final result = await usecase.execute(orderId: 'order-1');

    expect(_ok(result), same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('a refusal is a plain failure without a re-read', () async {
    when(() => mainnetRepository.confirmWithdrawOrder('order-1')).thenAnswer(
      (_) async => const WriteRefused(ExchangeRefusal(rpcCode: -32603)),
    );

    final result = await usecase.execute(orderId: 'order-1');
    verifyNever(() => mainnetRepository.getOrder(any()));

    expect(
      _err(result),
      isA<WithdrawUnexpectedFailure>().having(
        (failure) => failure.logMessage,
        'logMessage',
        isNot(contains('Montreal')),
      ),
    );
  });

  test(
    'an unauthenticated confirmation is reported without a re-read',
    () async {
      when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
          .thenAnswer((_) async => const WriteSessionRejected());

      final result = await usecase.execute(orderId: 'order-1');

      expect(_err(result), isA<WithdrawUnauthenticatedFailure>());
      verifyNever(() => mainnetRepository.getOrder(any()));
    },
  );

  group('a confirmation whose outcome is unknown (WD-1)', () {
    setUp(() {
      when(
        () => mainnetRepository.confirmWithdrawOrder(
          'order-1',
          interacUpdate: any(named: 'interacUpdate'),
        ),
      ).thenAnswer((_) async => const WriteOutcomeUnknown('receive timeout'));
    });

    test('is a success when the re-read order is confirmed', () async {
      final confirmed = _MockWithdrawOrder();
      when(() => confirmed.orderStatus).thenReturn(OrderStatus.inProgress);
      when(() => mainnetRepository.getOrder('order-1'))
          .thenAnswer((_) async => Ok(confirmed));

      final result = await usecase.execute(orderId: 'order-1');

      expect(_ok(result), same(confirmed));
    });

    test('is a success when the confirm call throws and the re-read order is '
        'confirmed', () async {
      when(() => mainnetRepository.confirmWithdrawOrder('order-1'))
          .thenThrow(Exception('receive timeout'));
      final confirmed = _MockWithdrawOrder();
      when(() => confirmed.orderStatus).thenReturn(OrderStatus.inProgress);
      when(() => mainnetRepository.getOrder('order-1'))
          .thenAnswer((_) async => Ok(confirmed));

      final result = await usecase.execute(orderId: 'order-1');

      expect(_ok(result), same(confirmed));
    });

    test(
      'saves the Interac details of an order confirmed on re-read',
      () async {
        final confirmed = _MockWithdrawOrder();
        when(() => confirmed.orderStatus).thenReturn(OrderStatus.completed);
        when(() => mainnetRepository.getOrder('order-1'))
            .thenAnswer((_) async => Ok(confirmed));
        when(
          () => recipients.updateInteracSecurityDetails(
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

        expect(_ok(result), same(confirmed));
        verify(
          () => recipients.updateInteracSecurityDetails(
            recipientId: 'recipient-1',
            email: 'person@example.com',
            securityQuestion: 'Favourite city?',
            securityAnswer: 'Montreal',
            isTestnet: false,
          ),
        ).called(1);
      },
    );

    test('is a plain failure when the order is still awaiting '
        'confirmation', () async {
      final pending = _MockWithdrawOrder();
      when(() => pending.orderStatus)
          .thenReturn(OrderStatus.awaitingConfirmation);
      when(() => mainnetRepository.getOrder('order-1'))
          .thenAnswer((_) async => Ok(pending));

      final result = await usecase.execute(orderId: 'order-1');

      expect(_err(result), isA<WithdrawUnexpectedFailure>());
    });

    test('stays unknown when the order cannot be re-read', () async {
      when(
        () => mainnetRepository.getOrder('order-1'),
      ).thenAnswer((_) async => const Err(ExchangeNetworkFailure('offline')));

      final result = await usecase.execute(orderId: 'order-1');

      expect(_err(result), isA<WithdrawConfirmOutcomeUnknownFailure>());
    });

    test('stays unknown on a status the app does not know', () async {
      final odd = _MockWithdrawOrder();
      when(() => odd.orderStatus).thenReturn(OrderStatus.unknown);
      when(() => mainnetRepository.getOrder('order-1'))
          .thenAnswer((_) async => Ok(odd));

      final result = await usecase.execute(orderId: 'order-1');

      expect(_err(result), isA<WithdrawConfirmOutcomeUnknownFailure>());
    });

    test('checkConfirmation re-reads without confirming again', () async {
      final confirmed = _MockWithdrawOrder();
      when(() => confirmed.orderStatus).thenReturn(OrderStatus.inProgress);
      when(() => mainnetRepository.getOrder('order-1'))
          .thenAnswer((_) async => Ok(confirmed));

      final result = await usecase.checkConfirmation(orderId: 'order-1');

      expect(_ok(result), same(confirmed));
      verifyNever(() => mainnetRepository.confirmWithdrawOrder(any()));
    });
  });
}
