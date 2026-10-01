import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/errors/confidential_sepa_not_activated_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

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

  void stubPlaceOrder(
    _MockExchangeOrderRepository repository,
    WithdrawOrder order,
  ) {
    when(
      () => repository.placeWithdrawalOrder(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        paymentProcessor: any(named: 'paymentProcessor'),
        paymentDescription: any(named: 'paymentDescription'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) async => order);
  }

  test('validates and submits trimmed Interac security details', () async {
    final order = _MockWithdrawOrder();
    stubPlaceOrder(mainnetRepository, order);

    final result = _ok(
      await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.interacEmailCad,
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
        paymentProcessor: null,
        paymentDescription: null,
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    ).called(1);
  });

  test('keeps non-Interac withdrawal payload unchanged', () async {
    final order = _MockWithdrawOrder();
    stubPlaceOrder(mainnetRepository, order);

    final result = _ok(
      await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.bankTransferCad,
      ),
    );

    expect(result.order, same(order));
    expect(result.interacSecurityDetails, isNull);
    verify(
      () => mainnetRepository.placeWithdrawalOrder(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        paymentProcessor: null,
        paymentDescription: null,
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
        recipientType: RecipientType.interacEmailCad,
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
        recipientType: RecipientType.interacEmailCad,
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
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    stubPlaceOrder(testnetRepository, order);

    final result = _ok(
      await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.bankTransferCad,
      ),
    );

    expect(result.order, same(order));
    verifyZeroInteractions(mainnetRepository);
  });

  test('sanitizes unexpected failures', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('Montreal'));

    final result = await usecase.execute(
      fiatAmount: 125,
      recipientId: 'recipient-1',
      recipientType: RecipientType.bankTransferCad,
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
    test('maps confidential SEPA to the confidential processor', () async {
      final order = _MockWithdrawOrder();
      stubPlaceOrder(mainnetRepository, order);

      final result = await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.confidentialSepaEur,
      );

      expect(_ok(result).order, same(order));
      verify(
        () => mainnetRepository.placeWithdrawalOrder(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.confidential,
          paymentDescription: null,
          securityQuestion: null,
          securityAnswer: null,
        ),
      ).called(1);
    });

    test('maps regular SEPA and forwards the description', () async {
      final order = _MockWithdrawOrder();
      stubPlaceOrder(mainnetRepository, order);

      final result = await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.sepaEur,
        paymentDescription: 'invoice 42',
      );

      expect(_ok(result).order, same(order));
      verify(
        () => mainnetRepository.placeWithdrawalOrder(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          paymentProcessor: SepaPaymentProcessor.regular,
          paymentDescription: 'invoice 42',
          securityQuestion: null,
          securityAnswer: null,
        ),
      ).called(1);
    });

    test('maps an inactive confidential payee to the typed failure', () async {
      when(
        () => mainnetRepository.placeWithdrawalOrder(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          paymentProcessor: any(named: 'paymentProcessor'),
          paymentDescription: any(named: 'paymentDescription'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).thenThrow(const ConfidentialSepaNotActivatedException());

      final result = await usecase.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientType: RecipientType.confidentialSepaEur,
      );

      expect(_err(result), isA<WithdrawConfidentialSepaNotActivatedFailure>());
    });
  });
}
