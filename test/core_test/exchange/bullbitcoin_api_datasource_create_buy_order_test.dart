import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

const _ordersPath = '/ak/api-orders';

Response<dynamic> _response(Map<String, dynamic> body) => Response(
  requestOptions: RequestOptions(path: _ordersPath),
  statusCode: 200,
  data: body,
);

Map<String, dynamic> _limit({
  required Object amount,
  required String currencyCode,
  required String conditionalOperator,
}) => {
  'entity': 'ORDER',
  'code': 'LIMIT_AMOUNT',
  'amount': amount,
  'conditionalOperator': conditionalOperator,
  'currencyCode': currencyCode,
  'timePeriod': 'DAY',
  'recurringFrequency': 'DAILY',
};

void main() {
  late _MockDio dio;
  late BullbitcoinApiDatasource datasource;

  setUp(() {
    dio = _MockDio();
    datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);
  });

  Future<OrderModel> createBuyOrder() => datasource.createBuyOrder(
    apiKey: 'key',
    fiatCurrency: FiatCurrency.cad,
    orderAmount: const FiatAmount(5),
    network: OrderBitcoinNetwork.liquid,
    isOwner: true,
    address: 'lq1address',
  );

  void stub(Map<String, dynamic> body) {
    when(
      () => dio.post<dynamic>(
        _ordersPath,
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response(body));
  }

  group('BullbitcoinApiDatasource.createBuyOrder error parsing', () {
    test('aggregate minimums throw the lowest one with its currency', () async {
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {
                'amount': '5',
                'limit': _limit(
                  amount: '20',
                  currencyCode: 'CAD',
                  conditionalOperator: 'GREATER_THAN_OR_EQUAL',
                ),
                'accessDescription': 'e-Transfer',
              },
              {
                'amount': '5',
                'limit': _limit(
                  amount: 50,
                  currencyCode: 'CAD',
                  conditionalOperator: 'GREATER_THAN_OR_EQUAL',
                ),
                'accessDescription': 'Wire',
              },
            ],
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<BullBitcoinApiMinAmountException>()
              .having((e) => e.minAmount, 'minAmount', 20)
              .having((e) => e.currency, 'currency', 'CAD'),
        ),
      );
    });

    test('aggregate maximums throw the highest one', () async {
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {
                'limit': _limit(
                  amount: 1000,
                  currencyCode: 'CAD',
                  conditionalOperator: 'LESS_THAN_OR_EQUAL',
                ),
              },
              {
                'limit': _limit(
                  amount: 2500.5,
                  currencyCode: 'CAD',
                  conditionalOperator: 'LESS_THAN_OR_EQUAL',
                ),
              },
            ],
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<BullBitcoinApiMaxAmountException>()
              .having((e) => e.maxAmount, 'maxAmount', 2500.5)
              .having((e) => e.currency, 'currency', 'CAD'),
        ),
      );
    });

    test('mixed operators fall back to the generic error', () async {
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {
                'limit': _limit(
                  amount: 20,
                  currencyCode: 'CAD',
                  conditionalOperator: 'GREATER_THAN_OR_EQUAL',
                ),
              },
              {
                'limit': _limit(
                  amount: 1000,
                  currencyCode: 'CAD',
                  conditionalOperator: 'LESS_THAN_OR_EQUAL',
                ),
              },
            ],
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No valid payment options available'),
          ),
        ),
      );
    });

    test('mixed currencies fall back to the generic error', () async {
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {
                'limit': _limit(
                  amount: 20,
                  currencyCode: 'CAD',
                  conditionalOperator: 'GREATER_THAN_OR_EQUAL',
                ),
              },
              {
                'limit': _limit(
                  amount: 0.0002,
                  currencyCode: 'BTC',
                  conditionalOperator: 'GREATER_THAN_OR_EQUAL',
                ),
              },
            ],
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No valid payment options available'),
          ),
        ),
      );
    });

    test('single reason.limit shape is still supported', () async {
      stub({
        'error': {
          'message': 'Amount too low',
          'data': {
            'reason': {
              'limit': _limit(
                amount: '0.0001',
                currencyCode: 'BTC',
                conditionalOperator: 'GREATER_THAN_OR_EQUAL',
              ),
            },
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<BullBitcoinApiMinAmountException>()
              .having((e) => e.minAmount, 'minAmount', 0.0001)
              .having((e) => e.currency, 'currency', 'BTC'),
        ),
      );
    });

    test('an empty reasons array falls back to the generic error', () async {
      // Some rejection paths (group-access denial, non-positive amounts)
      // produce no structured reason at all.
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': <dynamic>[],
            'details': <dynamic>[null, null],
          },
        },
        'result': null,
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No valid payment options available'),
          ),
        ),
      );
    });

    test('reasons without limits fall back to the generic error', () async {
      stub({
        'error': {
          'message': 'No valid payment options available after applying limits',
          'data': {
            'reasons': [
              {'accessDescription': 'e-Transfer'},
              {'amount': '5'},
            ],
            'details': <dynamic>[null],
          },
        },
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No valid payment options available'),
          ),
        ),
      );
    });

    test('an error with data but no reason at all still throws', () async {
      stub({
        'error': {
          'message': 'Order could not be created',
          'data': {
            'details': <dynamic>[null, null],
          },
        },
        'result': null,
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Order could not be created'),
          ),
        ),
      );
    });

    test('an unrecognized error never falls through to the result', () async {
      stub({
        'error': {'message': 'Something else went wrong', 'data': null},
        'result': null,
      });

      await expectLater(
        createBuyOrder(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Something else went wrong'),
          ),
        ),
      );
    });

    test('an error with no message at all still throws', () async {
      stub({'error': <String, dynamic>{}});

      await expectLater(createBuyOrder(), throwsA(isA<Exception>()));
    });
  });
}
