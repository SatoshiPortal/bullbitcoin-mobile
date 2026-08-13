import 'dart:async';

import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses the measured quote response and always sends the fixed flag',
    () async {
      late Map<String, dynamic> requestBody;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestBody = Map<String, dynamic>.from(options.data as Map);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'jsonrpc': '2.0',
                    'id': _requestId(options),
                    'result': {
                      'inAmount': 0.001,
                      'outAmount': 0.00099,
                      'inPaymentProcessorCurrencyCode': 'LBTC',
                      'outPaymentProcessorCurrencyCode': 'BTC',
                      'orderFees': [
                        {'percent': 1},
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );
      final datasource = ExchangePublicApiDatasource(dio);

      final quote = await datasource.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      );

      expect(requestBody['method'], 'getBestSwapOption');
      expect(requestBody['params'], {
        'amount': 0.001,
        'isInAmountFixed': true,
        'inNetwork': 'liquid',
        'outNetwork': 'bitcoin',
      });
      expect(quote.inAmount, '0.001');
      expect(quote.outAmount, '0.00099');
      expect(quote.inCurrency, 'LBTC');
      expect(quote.outCurrency, 'BTC');
      expect(quote.feePercents, ['1']);
    },
  );

  test('serializes all six directed network pairs', () async {
    final requestParams = <Map<String, dynamic>>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = Map<String, dynamic>.from(options.data as Map);
            requestParams.add(Map<String, dynamic>.from(body['params'] as Map));
            handler.resolve(_quoteResponse(options));
          },
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);
    final pairs = [
      (OrderSwapNetwork.bitcoin, OrderSwapNetwork.liquid),
      (OrderSwapNetwork.bitcoin, OrderSwapNetwork.lightning),
      (OrderSwapNetwork.liquid, OrderSwapNetwork.bitcoin),
      (OrderSwapNetwork.liquid, OrderSwapNetwork.lightning),
      (OrderSwapNetwork.lightning, OrderSwapNetwork.bitcoin),
      (OrderSwapNetwork.lightning, OrderSwapNetwork.liquid),
    ];

    for (final (input, output) in pairs) {
      await datasource.getBestSwapOption(
        amountSat: BigInt.from(105000),
        isInAmountFixed: true,
        inNetwork: input,
        outNetwork: output,
      );
    }

    expect(
      requestParams
          .map((params) => (params['inNetwork'], params['outNetwork']))
          .toList(),
      [
        ('bitcoin', 'liquid'),
        ('bitcoin', 'lightning'),
        ('liquid', 'bitcoin'),
        ('liquid', 'lightning'),
        ('lightning', 'bitcoin'),
        ('lightning', 'liquid'),
      ],
    );
    expect(
      requestParams,
      everyElement(
        allOf(
          containsPair('amount', 0.00105),
          containsPair('isInAmountFixed', true),
        ),
      ),
    );
  });

  test('maps a plain-text HTTP 429 and Retry-After', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 429,
              data: 'Too Many Requests',
              headers: Headers.fromMap({
                'retry-after': ['1'],
              }),
            ),
          ),
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    await expectLater(
      datasource.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
      throwsA(
        isA<ExchangeRateLimitException>().having(
          (error) => error.retryAfterSeconds,
          'retryAfterSeconds',
          1,
        ),
      ),
    );
  });

  test('maps HTTP 418 to the app update signal', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 418,
              data: 'Upgrade Required',
            ),
          ),
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    await expectLater(
      datasource.getBestSwapOption(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
      throwsA(isA<ExchangeAppUpdateRequiredException>()),
    );
  });

  test('parses the measured nested API limit error', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'jsonrpc': '2.0',
                'id': _requestId(options),
                'error': {
                  'code': -32011,
                  'message': 'Transaction amount is below the minimum',
                  'data': {
                    'apiError': {
                      'code': 'ERR_ORD_LMT001',
                      'messageData': {
                        'limit': '0.00100000',
                        'operator': 'greater than or equal',
                      },
                    },
                  },
                },
              },
            ),
          ),
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    await expectLater(
      datasource.getBestSwapOption(
        amountSat: BigInt.from(10000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.bitcoin,
        outNetwork: OrderSwapNetwork.lightning,
      ),
      throwsA(
        isA<ExchangeRpcException>()
            .having((error) => error.rpcCode, 'rpcCode', -32011)
            .having((error) => error.apiCode, 'apiCode', 'ERR_ORD_LMT001')
            .having((error) => error.limit, 'limit', '0.00100000')
            .having(
              (error) => error.limitOperator,
              'limitOperator',
              'greater than or equal',
            ),
      ),
    );
  });

  test('parses the measured initial order response', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'jsonrpc': '2.0',
                'id': _requestId(options),
                'result': {
                  'orderId': '11111111-1111-1111-1111-111111111111',
                  'orderNumber': 123,
                  'orderType': 'Swap',
                  'orderStatus': 'In_pending',
                  'payinAmount': 0.001,
                  'payinCurrency': 'LBTC',
                  'payinMethod': 'Liquid Network',
                  'payinStatus': 'Awaiting payment',
                  'payoutAmount': 0.00099,
                  'payoutCurrency': 'BTC',
                  'payoutMethod': 'Bitcoin On-Chain',
                  'payoutStatus': 'Not started',
                  'message': {'code': 'PAYMENT_NOT_DETECTED'},
                  'createdAt': '2026-08-05T21:57:07.371Z',
                  'confirmationDeadline': '2026-08-05T22:02:07.362Z',
                  'completedAt': null,
                  'sentAt': null,
                  'bitcoinAddress': 'tb1qexample',
                  'bitcoinTransactionId': null,
                  'liquidAddress': 'tlq1example',
                  'liquidTransactionId': null,
                },
              },
            ),
          ),
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    final order = await datasource.createOrderSwap(
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
      destinationAddress: 'tb1qexample',
      fallbackAddress: 'tlq1example',
    );

    expect(order.orderStatus, 'In_pending');
    expect(order.payinAmount, '0.001');
    expect(order.liquidTransactionId, isNull);
  });

  test(
    'omits fallbackAddress when the backend supports atomic refund',
    () async {
      late Map<String, dynamic> requestParams;
      late String sentRequestId;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final body = Map<String, dynamic>.from(options.data as Map);
              sentRequestId = body['id'] as String;
              requestParams = Map<String, dynamic>.from(body['params'] as Map);
              handler.resolve(_receiveOrderResponse(options));
            },
          ),
        );
      final datasource = ExchangePublicApiDatasource(dio);

      final order = await datasource.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      );

      expect(requestParams, isNot(contains('fallbackAddress')));
      expect(sentRequestId, 'request-1');
      expect(order.lightningInvoice, 'lntb-invoice');
    },
  );

  test('sends the measured summary request and parses its result', () async {
    late Map<String, dynamic> requestBody;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestBody = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(_receiveOrderResponse(options));
          },
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    final order = await datasource.getOrderSwapSummary('receive-order');

    expect(requestBody['method'], 'getOrderSwapSummary');
    expect(requestBody['params'], {'orderId': 'receive-order'});
    expect(order.orderId, '11111111-1111-1111-1111-111111111111');
    expect(order.payinCurrency, 'BTC');
    expect(order.payinMethod, 'Lightning Invoice (BOLT11)');
    expect(order.payoutCurrency, 'LBTC');
    expect(order.payoutMethod, 'Liquid Network');
  });

  test('rejects a response carrying a different request id', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final response = _receiveOrderResponse(options);
            (response.data as Map<String, dynamic>)['id'] = 'other-request';
            handler.resolve(response);
          },
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    await expectLater(
      datasource.createOrderSwap(
        requestId: 'request-1',
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      ),
      throwsA(isA<ExchangeResponseException>()),
    );
  });

  test('does not retry an ambiguous network failure', () async {
    var requestCount = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    await expectLater(
      datasource.createOrderSwap(
        amountSat: BigInt.from(100000),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: 'tlq1destination',
        fallbackAddress: null,
      ),
      throwsA(isA<ExchangeNetworkException>()),
    );
    expect(requestCount, 1);
  });

  test('serializes all public RPC requests', () async {
    var activeRequests = 0;
    var maximumActiveRequests = 0;
    final firstRequestStarted = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    var requestCount = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            activeRequests++;
            maximumActiveRequests = maximumActiveRequests < activeRequests
                ? activeRequests
                : maximumActiveRequests;
            requestCount++;
            if (requestCount == 1) {
              firstRequestStarted.complete();
              await releaseFirstRequest.future;
            }
            handler.resolve(_quoteResponse(options));
            activeRequests--;
          },
        ),
      );
    final datasource = ExchangePublicApiDatasource(dio);

    final first = datasource.getBestSwapOption(
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );
    await firstRequestStarted.future;
    final second = datasource.getBestSwapOption(
      amountSat: BigInt.from(100000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );
    await Future<void>.delayed(Duration.zero);

    expect(requestCount, 1);
    releaseFirstRequest.complete();
    await Future.wait([first, second]);
    expect(maximumActiveRequests, 1);
    expect(requestCount, 2);
  });
}

Response<dynamic> _quoteResponse(RequestOptions options) => Response<dynamic>(
  requestOptions: options,
  statusCode: 200,
  data: {
    'jsonrpc': '2.0',
    'id': _requestId(options),
    'result': {
      'inAmount': 0.001,
      'outAmount': 0.00099,
      'inPaymentProcessorCurrencyCode': 'LBTC',
      'outPaymentProcessorCurrencyCode': 'BTC',
      'orderFees': <dynamic>[],
    },
  },
);

Response<dynamic> _receiveOrderResponse(RequestOptions options) =>
    Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: {
        'jsonrpc': '2.0',
        'id': _requestId(options),
        'result': {
          'orderId': '11111111-1111-1111-1111-111111111111',
          'orderNumber': 123,
          'orderType': 'Swap',
          'orderStatus': 'In_pending',
          'payinAmount': 0.001,
          'payinCurrency': 'BTC',
          'payinMethod': 'Lightning Invoice (BOLT11)',
          'payinStatus': 'Awaiting payment',
          'payoutAmount': 0.00099,
          'payoutCurrency': 'LBTC',
          'payoutMethod': 'Liquid Network',
          'payoutStatus': 'Not started',
          'message': {'code': 'PAYMENT_NOT_DETECTED'},
          'createdAt': '2026-08-05T21:57:07.371Z',
          'confirmationDeadline': '2026-08-05T22:02:07.362Z',
          'completedAt': null,
          'sentAt': null,
          'lightningInvoice': 'lntb-invoice',
          'liquidAddress': 'tlq1destination',
          'liquidTransactionId': null,
        },
      },
    );

String _requestId(RequestOptions options) =>
    (options.data as Map<String, dynamic>)['id'] as String;
