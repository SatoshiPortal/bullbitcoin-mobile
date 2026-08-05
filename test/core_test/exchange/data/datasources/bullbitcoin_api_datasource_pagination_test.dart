import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _orderJson(String id) => {
  'orderId': id,
  'orderType': 'Buy Bitcoin',
  'orderNumber': int.parse(id.substring(1)),
  'exchangeRateAmount': 100000,
  'exchangeRateCurrency': 'CAD',
  'payinAmount': 100,
  'payinCurrency': 'CAD',
  'payoutAmount': 0.001,
  'payoutCurrency': 'BTC',
  'orderStatus': 'Completed',
  'payinStatus': 'Completed',
  'payoutStatus': 'Completed',
  'createdAt': '2026-07-29T12:00:00.000Z',
  'message': <String, dynamic>{'code': '', 'message': ''},
  'payinMethod': 'CAD Balance',
  'payoutMethod': 'Bitcoin',
  'triggerType': 'MANUAL',
  'confirmationDeadline': '2026-07-29T12:05:00.000Z',
};

void main() {
  late _MockDio dio;
  late BullbitcoinApiDatasource datasource;
  late List<int> requestedPages;

  setUp(() {
    dio = _MockDio();
    datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);
    requestedPages = [];
  });

  void stubPages(Map<int, List<Map<String, dynamic>>> pages) {
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      final params = data['params'] as Map<String, dynamic>;
      final paginator = params['paginator'] as Map<String, dynamic>;
      final page = paginator['page'] as int;
      requestedPages.add(page);

      return Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-orders'),
        statusCode: 200,
        data: {
          'result': {'elements': pages[page] ?? <Map<String, dynamic>>[]},
        },
      );
    });
  }

  test('loads every page instead of stopping after the first one', () async {
    stubPages({
      1: [_orderJson('o1'), _orderJson('o2')],
      2: [_orderJson('o3')],
    });

    final orders = await datasource.listOrderSummaries(
      apiKey: 'key',
      pageSize: 2,
    );

    expect(orders.map((order) => order.orderId), ['o1', 'o2', 'o3']);
    expect(requestedPages, [1, 2]);
  });

  test('stops when the backend repeats a full page', () async {
    final repeatedPage = [_orderJson('o1'), _orderJson('o2')];
    stubPages({1: repeatedPage, 2: repeatedPage});

    final orders = await datasource.listOrderSummaries(
      apiKey: 'key',
      pageSize: 2,
    );

    expect(orders.map((order) => order.orderId), ['o1', 'o2']);
    expect(requestedPages, [1, 2]);
  });
}
