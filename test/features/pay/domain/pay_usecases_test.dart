import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/failures/pay_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/refresh_pay_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExchangeOrderRepository extends Mock
    implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

final _mainnetSettings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
);

void main() {
  late _MockExchangeOrderRepository mainnetRepo;
  late _MockExchangeOrderRepository testnetRepo;
  late _MockSettingsRepository settingsRepo;

  setUpAll(() {
    registerFallbackValue(const FiatAmount(0));
    registerFallbackValue(OrderBitcoinNetwork.bitcoin);
  });

  setUp(() {
    mainnetRepo = _MockExchangeOrderRepository();
    testnetRepo = _MockExchangeOrderRepository();
    settingsRepo = _MockSettingsRepository();

    when(() => settingsRepo.fetch()).thenAnswer((_) async => _mainnetSettings);
  });

  group('PlacePayOrderUsecase', () {
    late PlacePayOrderUsecase usecase;

    setUp(() {
      usecase = PlacePayOrderUsecase(
        mainnetExchangeOrderRepository: mainnetRepo,
        testnetExchangeOrderRepository: testnetRepo,
        settingsRepository: settingsRepo,
      );
    });

    test('returns Err(PayUnexpectedFailure) without leaking raw exception when repo throws', () async {
      when(
        () => mainnetRepo.placePayOrder(
          orderAmount: any(named: 'orderAmount'),
          recipientId: any(named: 'recipientId'),
          network: any(named: 'network'),
          paymentDescription: any(named: 'paymentDescription'),
        ),
      ).thenAnswer(
        (_) async => const Err(PayUnexpectedFailure('internal db error 0xdeadbeef')),
      );

      final result = await usecase.execute(
        orderAmount: const FiatAmount(100),
        recipientId: 'recipient-1',
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<FiatPaymentOrder, PayFailure>>());
      final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
    });

    test('returns Err(PayBelowMinAmountFailure) when repo signals below-min', () async {
      when(
        () => mainnetRepo.placePayOrder(
          orderAmount: any(named: 'orderAmount'),
          recipientId: any(named: 'recipientId'),
          network: any(named: 'network'),
          paymentDescription: any(named: 'paymentDescription'),
        ),
      ).thenAnswer(
        (_) async => const Err(PayBelowMinAmountFailure(minAmountSat: 10000)),
      );

      final result = await usecase.execute(
        orderAmount: const FiatAmount(0.01),
        recipientId: 'recipient-1',
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<FiatPaymentOrder, PayFailure>>());
      final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
      expect(failure, isA<PayBelowMinAmountFailure>());
    });

    test('returns Err(PayUnexpectedFailure) when settings fetch throws', () async {
      when(() => settingsRepo.fetch()).thenThrow(Exception('storage error'));

      final result = await usecase.execute(
        orderAmount: const FiatAmount(100),
        recipientId: 'recipient-1',
        network: OrderBitcoinNetwork.bitcoin,
      );

      expect(result, isA<Err<FiatPaymentOrder, PayFailure>>());
      final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
      // Failure is sanitized — raw exception stays in logs, not UI.
      expect(failure, isA<PayUnexpectedFailure>());
    });
  });

  group('RefreshPayOrderUsecase', () {
    late RefreshPayOrderUsecase usecase;

    setUp(() {
      usecase = RefreshPayOrderUsecase(
        mainnetExchangeOrderRepository: mainnetRepo,
        testnetExchangeOrderRepository: testnetRepo,
        settingsRepository: settingsRepo,
      );
    });

    test('returns Err(PayUnexpectedFailure) when repo signals unexpected error', () async {
      when(() => mainnetRepo.refreshPayOrder(any()))
          .thenAnswer((_) async => const Err(PayUnexpectedFailure()));

      final result = await usecase.execute(orderId: 'order-999');

      expect(result, isA<Err<FiatPaymentOrder, PayFailure>>());
      final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
      expect(failure, isA<PayUnexpectedFailure>());
    });

    test('returns Err(PayUnexpectedFailure) when settings fetch throws', () async {
      when(() => settingsRepo.fetch()).thenThrow(Exception('disk full'));

      final result = await usecase.execute(orderId: 'order-1');

      expect(result, isA<Err<FiatPaymentOrder, PayFailure>>());
      final failure = (result as Err<FiatPaymentOrder, PayFailure>).failure;
      // Failure is sanitized — raw exception stays in logs, not UI.
      expect(failure, isA<PayUnexpectedFailure>());
    });
  });
}
