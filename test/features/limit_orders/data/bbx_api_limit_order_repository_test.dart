import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/data/bbx_api_limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderRepo extends Mock implements bbx.OrderRepo {}

class _MockPricerRepo extends Mock implements bbx.PricerRepo {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(bbx.ListRequest<bbx.ListLimitOrdersPayload>());
  });

  final json = <String, dynamic>{
    'limitOrderId': 'lo-1',
    'limitOrderNbr': 'LO-1',
    'userId': 'user-1',
    'userNbr': 1,
    'fiatAmount': '100.00',
    'currencyCode': 'CAD',
    'limitPrice': '90000.00',
    'estimatedBtcAmount': '0.00111111',
    'status': 'ACTIVE',
    'createdAt': '2026-07-28T12:00:00.000Z',
    'expiresAt': '2026-08-28T12:00:00.000Z',
    'lastCheckedAt': '2026-07-28T12:00:00.000Z',
    'address': 'bc1qexample',
  };

  test('a package limit order maps to the app entity', () {
    final mapped = BbxApiLimitOrderRepository.toEntity(
      bbx.LimitOrderModel.fromJson(json),
    );

    expect(mapped.id, 'lo-1');
    expect(mapped.number, 'LO-1');
    expect(mapped.fiatAmount, 100);
    expect(mapped.currencyCode, 'CAD');
    expect(mapped.limitPrice, 90000);
    expect(mapped.estimatedBtcAmount, 0.00111111);
    expect(mapped.status, LimitOrderStatus.active);
    expect(mapped.createdAt, DateTime.utc(2026, 7, 28, 12));
    expect(mapped.expiresAt, DateTime.utc(2026, 8, 28, 12));
    expect(mapped.address, 'bc1qexample');
  });

  group('mapFailure', () {
    LimitOrdersFailure map(bbx.ApiError error) =>
        BbxApiLimitOrderRepository.mapFailure(
          error,
          LimitOrdersLoadFailure.new,
        );

    test('maps the order-trigger codes', () {
      const codes = <String, Type>{
        'ERR_ORDTRG_LOMAX429': LimitOrdersMaximumActiveFailure,
        'ERR_ORDTRG_LO404': LimitOrderNotFoundFailure,
        'ERR_ORDTRG_ADDR400': LimitOrderInvalidAddressFailure,
        'ERR_OTHER': LimitOrdersLoadFailure,
      };
      for (final entry in codes.entries) {
        expect(
          map(
            bbx.ApiError(
              serverMessage: 'x',
              rpcErrorData: {
                'apiError': {'code': entry.key},
              },
            ),
          ).runtimeType,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('a 401 means the account is unavailable', () {
      expect(
        map(const bbx.ApiError(serverMessage: 'x', httpStatus: 401)),
        isA<LimitOrdersAccountUnavailableFailure>(),
      );
    });

    test('transport problems and a missing key are unexpected', () {
      expect(
        map(
          const bbx.ApiError(
            serverMessage: 'x',
            kind: bbx.ApiErrorKind.network,
          ),
        ),
        isA<LimitOrdersUnexpectedFailure>(),
      );
      expect(
        map(
          const bbx.ApiError(
            serverMessage: 'x',
            kind: bbx.ApiErrorKind.unauthenticated,
            code: 'ERR_API_KEY_MISSING',
          ),
        ),
        isA<LimitOrdersUnexpectedFailure>(),
      );
    });
  });

  group('environment', () {
    late _MockOrderRepo mainnetOrders;
    late _MockOrderRepo testnetOrders;
    late _MockPricerRepo mainnetPrices;
    late _MockSettingsRepository settingsRepository;
    late _MockSettings settings;
    late BbxApiLimitOrderRepository repository;

    BbxApiDatasource apiWith(bbx.OrderRepo orders, [bbx.PricerRepo? prices]) {
      final api = _MockBbxApi();
      when(() => api.orders).thenReturn(orders);
      if (prices != null) when(() => api.pricer).thenReturn(prices);
      return BbxApiDatasource(api);
    }

    setUp(() {
      mainnetOrders = _MockOrderRepo();
      testnetOrders = _MockOrderRepo();
      mainnetPrices = _MockPricerRepo();
      settingsRepository = _MockSettingsRepository();
      settings = _MockSettings();
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
      repository = BbxApiLimitOrderRepository(
        mainnet: apiWith(mainnetOrders, mainnetPrices),
        testnet: apiWith(testnetOrders),
        settingsRepository: settingsRepository,
      );
    });

    test('uses the testnet client on testnet', () async {
      when(() => settings.environment).thenReturn(Environment.testnet);
      when(() => testnetOrders.getLimitOrder(orderId: 'lo-1')).thenAnswer(
        (_) async =>
            bbx.ApiResult.success(data: bbx.LimitOrderModel.fromJson(json)),
      );

      final result = await repository.get('lo-1');

      expect(result, isA<Ok<LimitOrder, LimitOrdersFailure>>());
      verifyNever(() => mainnetOrders.getLimitOrder(orderId: 'lo-1'));
    });

    test('lists active orders with the ACTIVE filter', () async {
      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(() => mainnetOrders.listLimitOrders(any())).thenAnswer(
        (_) async => bbx.ApiResult.success(
          data: bbx.ListResponse<bbx.LimitOrderModel>(
            items: [
              bbx.LimitOrderModel.fromJson(json),
              bbx.LimitOrderModel.fromJson({
                ...json,
                'limitOrderId': 'lo-2',
                'status': 'CANCELLED',
              }),
            ],
            totalElements: 2,
          ),
        ),
      );

      final result = await repository.listActive();

      final orders = (result as Ok<List<LimitOrder>, LimitOrdersFailure>).value;
      expect(orders.map((o) => o.id), ['lo-1']);
      final request =
          verify(
                () => mainnetOrders.listLimitOrders(captureAny()),
              ).captured.single
              as bbx.ListRequest<bbx.ListLimitOrdersPayload>;
      expect(request.toParams(), {
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': 1, 'pageSize': 50},
        'filters': {'status': 'ACTIVE'},
      });
    });

    test('a rate for an unsupported currency is a load failure', () async {
      when(() => settings.environment).thenReturn(Environment.mainnet);

      final result = await repository.getRate('XYZ');

      expect(
        result,
        isA<Err<LimitOrderRate, LimitOrdersFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<LimitOrdersLoadFailure>(),
        ),
      );
    });

    test('a rate without its prices fails without a crash', () async {
      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(
        () => mainnetPrices.getUserRate(
          fromCurrency: bbx.RateCurrency.cad,
          toCurrency: bbx.RateCurrency.btc,
        ),
      ).thenAnswer(
        (_) async => bbx.ApiResult<bbx.Rate>.success(
          data: bbx.RateModel.fromJson({'fromCurrency': 'CAD'}),
        ),
      );

      final result = await repository.getRate('CAD');

      expect(
        result,
        isA<Err<LimitOrderRate, LimitOrdersFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<LimitOrdersUnexpectedFailure>(),
        ),
      );
    });
  });
}

class _MockBbxApi extends Mock implements bbx.BbxApi {}
