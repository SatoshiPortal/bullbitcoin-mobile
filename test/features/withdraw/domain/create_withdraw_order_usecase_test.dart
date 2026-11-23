import 'package:exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrders extends Mock implements ExchangeOrders {}

class _MockSettingsRepository extends Mock implements Preferences {}

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
  late CreateWithdrawOrderUsecase usecase;

  setUp(() {
    mainnetRepository = _MockExchangeOrders();
    testnetRepository = _MockExchangeOrders();
    settingsRepository = _MockSettingsRepository();
    usecase = CreateWithdrawOrderUsecase(
      exchange: exchangeForTesting(
        orders: (environment) => environment == ExchangeEnvironment.testnet
            ? testnetRepository
            : mainnetRepository,
      ),
      settingsRepository: settingsRepository,
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

  test('regtest refuses withdrawal before backend IO', () async {
    when(settingsRepository.fetch).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    expect(
      await usecase.execute(fiatAmount: 100, recipientId: 'recipient'),
      isA<Err>(),
    );
    verifyZeroInteractions(mainnetRepository);
    verifyZeroInteractions(testnetRepository);
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
    ).thenAnswer((_) async => Ok(order));

    final result = _ok(
      await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientEmail: 'person@example.com',
        securityQuestion: '  Favourite city?  ',
        securityAnswer: '  Montreal  ',
      ),
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
    ).thenAnswer((_) async => Ok(order));

    final result = _ok(
      await usecase.execute(fiatAmount: 125, recipientId: 'recipient-1'),
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
      final result = await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientEmail: 'person@example.com',
        securityQuestion: 'Favourite city?',
      );

      expect(_err(result), isA<WithdrawUnexpectedFailure>());
      verifyZeroInteractions(mainnetRepository);
      verifyZeroInteractions(testnetRepository);
    },
  );

  test(
    'rejects invalid Interac security details before the API call',
    () async {
      final result = await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientEmail: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal!',
      );

      expect(_err(result), isA<WithdrawUnexpectedFailure>());
      verifyZeroInteractions(mainnetRepository);
      verifyZeroInteractions(testnetRepository);
    },
  );

  test('routes testnet orders to the testnet repository', () async {
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
    when(
      () => testnetRepository.placeWithdrawalOrder(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => Ok(order));

    final result = _ok(
      await usecase.execute(fiatAmount: 125, recipientId: 'recipient-1'),
    );

    expect(result.order, same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('sanitizes unexpected failures', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('Montreal'));

    final result = await usecase.execute(
      fiatAmount: 125,
      recipientId: 'recipient-1',
    );

    expect(
      _err(result),
      isA<WithdrawUnexpectedFailure>().having(
        (failure) => failure.logMessage,
        'logMessage',
        isNot(contains('Montreal')),
      ),
    );
  });

  group('SEPA payment processor', () {
    setUpAll(() => registerFallbackValue(SepaPaymentProcessor.regular));

    void stubPlace(
      Future<Result<WithdrawOrder, ExchangeFailure>> Function() answer,
    ) {
      when(
        () => mainnetRepository.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
        ),
      ).thenAnswer((_) => answer());
    }

    SepaPaymentProcessor? sentProcessor() =>
        verify(
              () => mainnetRepository.placeWithdrawalOrder(
                fiatAmount: any(named: 'fiatAmount'),
                recipientId: any(named: 'recipientId'),
                paymentProcessor: captureAny(named: 'paymentProcessor'),
              ),
            ).captured.single
            as SepaPaymentProcessor?;

    for (final (type, processor) in [
      (RecipientType.sepaEur, SepaPaymentProcessor.regular),
      (RecipientType.confidentialSepaEur, SepaPaymentProcessor.confidential),
      (RecipientType.speiClabeMxn, null),
    ]) {
      test('a ${type.name} withdrawal sends $processor', () async {
        stubPlace(() async => Ok(_MockWithdrawOrder()));

        _ok(
          await usecase.execute(
            fiatAmount: 100,
            recipientId: 'recipient-1',
            recipientType: type,
          ),
        );

        expect(sentProcessor(), processor);
      });
    }

    test('an inactive virtual payee is its own failure', () async {
      stubPlace(
        () async => const Err(ExchangeConfidentialSepaInactiveFailure()),
      );

      final failure = _err(
        await usecase.execute(
          fiatAmount: 100,
          recipientId: 'recipient-1',
          recipientType: RecipientType.confidentialSepaEur,
        ),
      );

      expect(failure, isA<WithdrawConfidentialSepaNotActivatedFailure>());
    });
  });
}
