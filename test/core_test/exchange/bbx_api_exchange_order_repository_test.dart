import 'package:bb_mobile/core/exchange/domain/exchange_api_failure.dart';
import 'package:bb_mobile/bbx_api_setup.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/exchange/order_json_fixture.dart';

class _MockOrderRepo extends Mock implements bbx.OrderRepo {}

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeBuyPayload extends Fake implements bbx.CreateOrderBuyPayload {}

class _FakeSellPayload extends Fake implements bbx.SellToBalancePayload {}

class _FakeSellToRecipientPayload extends Fake
    implements bbx.SellToRecipientPayload {}

class _FakeWithdrawalPayload extends Fake
    implements bbx.CreateWithdrawalOrderPayload {}

class _FakeApiKey extends Fake implements ExchangeApiKeyModel {
  _FakeApiKey({this.isActive = true});

  @override
  final bool isActive;

  @override
  String get key => 'bbk_test';
}

void main() {
  setUpAll(() {
    registerFallbackValue(bbx.ListRequest());
    registerFallbackValue(_FakeSellPayload());
    registerFallbackValue(_FakeSellToRecipientPayload());
    registerFallbackValue(_FakeBuyPayload());
    registerFallbackValue(_FakeWithdrawalPayload());
  });

  late _MockOrderRepo orders;
  late _MockApiKeyDatasource apiKeys;
  late BbxApiExchangeOrderRepository repository;

  setUp(() {
    orders = _MockOrderRepo();
    apiKeys = _MockApiKeyDatasource();
    final container = _MockBbxApi();
    when(() => container.orders).thenReturn(orders);
    repository = BbxApiExchangeOrderRepository(
      api: BbxApiDatasource(container),
      apiKeyDatasource: apiKeys,
      isTestnet: true,
    );
    when(
      () => apiKeys.get(isTestnet: true),
    ).thenAnswer((_) async => _FakeApiKey());
  });

  Future<BuyOrder> placeBuy() => repository.placeBuyOrder(
    toAddress: 'bc1qexample',
    orderAmount: const FiatAmount(100),
    currency: FiatCurrency.cad,
    network: OrderBitcoinNetwork.bitcoin,
    isOwner: true,
  );

  void failBuyWith(bbx.ApiError error) {
    when(
      () => orders.createOrderBuy(params: any(named: 'params')),
    ).thenAnswer((_) async => bbx.ApiResult.apiFailure(error: error));
  }

  test('a buy order is built from the package order summary', () async {
    final summary = bbx.OrderSummaryModel.fromJson({
      'orderId': 'order-1',
      'orderType': 'Buy Bitcoin',
      'orderNumber': 1,
      'payinAmount': 100.0,
      'payinCurrency': 'CAD',
      'payoutAmount': 0.001,
      'payoutCurrency': 'BTC',
      'orderStatus': 'In progress',
      'payinStatus': 'Awaiting payment',
      'payoutStatus': 'Not started',
      'createdAt': '2026-07-28T12:00:00.000Z',
      'message': {'code': '', 'message': ''},
      'payinMethod': 'CAD Balance',
      'payoutMethod': 'Bitcoin On-Chain',
    });
    when(
      () => orders.createOrderBuy(params: any(named: 'params')),
    ).thenAnswer((_) async => bbx.ApiResult.success(data: summary));

    final order = await placeBuy();

    expect(order.orderId, 'order-1');
    final payload =
        verify(
              () => orders.createOrderBuy(params: captureAny(named: 'params')),
            ).captured.single
            as bbx.CreateOrderBuyPayload;
    expect(payload.toParams(), {
      'fiatCurrency': 'CAD',
      'fiatAmount': 100.0,
      'network': 'bitcoin',
      'address': 'bc1qexample',
      'isOwner': true,
    });
  });

  test('a minimum-amount rejection becomes the typed exception', () async {
    failBuyWith(
      const bbx.ApiError(
        serverMessage: 'rejected',
        rpcErrorData: {
          'reason': {
            'limit': {
              'amount': 20,
              'currencyCode': 'CAD',
              'conditionalOperator': 'GREATER_THAN_OR_EQUAL',
            },
          },
        },
      ),
    );

    await expectLater(
      placeBuy(),
      throwsA(
        isA<BullBitcoinApiMinAmountException>()
            .having((e) => e.minAmount, 'minAmount', 20)
            .having((e) => e.currency, 'currency', 'CAD'),
      ),
    );
  });

  test('a maximum-amount rejection becomes the typed exception', () async {
    failBuyWith(
      const bbx.ApiError(
        serverMessage: 'rejected',
        rpcErrorData: {
          'reason': {
            'limit': {
              'amount': '500',
              'currencyCode': 'CAD',
              'conditionalOperator': 'LESS_THAN_OR_EQUAL',
            },
          },
        },
      ),
    );

    await expectLater(
      placeBuy(),
      throwsA(isA<BullBitcoinApiMaxAmountException>()),
    );
  });

  test('a transport failure keeps its typed kind', () async {
    failBuyWith(
      const bbx.ApiError(
        serverMessage: 'Connection Time Out',
        kind: bbx.ApiErrorKind.timeout,
      ),
    );

    await expectLater(
      placeBuy(),
      throwsA(
        isA<BbxApiException>().having(
          (e) => e.error.kind,
          'kind',
          bbx.ApiErrorKind.timeout,
        ),
      ),
    );
  });

  test('an inactive Confidential SEPA payee keeps its exception', () async {
    when(
      () => orders.createWithdrawalOrder(params: any(named: 'params')),
    ).thenAnswer(
      (_) async => bbx.ApiResult.apiFailure(
        error: const bbx.ApiError(
          serverMessage: 'rejected',
          rpcErrorData: {
            'apiError': {'code': 'ERR_ORD_CSRCP400'},
          },
        ),
      ),
    );

    await expectLater(
      repository.placeWithdrawalOrder(fiatAmount: 10, recipientId: 'r1'),
      throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
    );
  });

  test('no stored key fails before calling the API', () async {
    when(() => apiKeys.get(isTestnet: true)).thenAnswer((_) async => null);

    await expectLater(placeBuy(), throwsA(isA<ApiKeyNotFoundException>()));
    verifyNever(() => orders.createOrderBuy(params: any(named: 'params')));
  });

  test('an inactive key fails before calling the API', () async {
    when(
      () => apiKeys.get(isTestnet: true),
    ).thenAnswer((_) async => _FakeApiKey(isActive: false));

    await expectLater(placeBuy(), throwsA(isA<ApiKeyInactiveException>()));
  });

  group('order reads', () {
    void stubOrders(List<Map<String, dynamic>> elements) {
      when(() => orders.listOrderSummaries(any())).thenAnswer((_) async {
        final items = <bbx.OrderSummaryModel>[];
        for (final json in elements) {
          try {
            items.add(
              bbx.OrderSummaryModel.fromJson(
                json,
                fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks,
              ),
            );
          } catch (_) {}
        }
        return bbx.ApiResult.success(
          data: bbx.ListResponse(items: items, totalElements: items.length),
        );
      });
    }

    test('lists the latest orders newest first', () async {
      stubOrders([orderJsonFixture()]);

      await repository.getOrders();

      final request =
          verify(() => orders.listOrderSummaries(captureAny())).captured.single
              as bbx.ListRequest;
      expect(request.toParams(), {
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': 1, 'pageSize': 50},
      });
    });

    test('keeps orders with values the package does not know', () async {
      stubOrders([
        orderJsonFixture(orderId: 'expired-1', orderStatus: 'Expired'),
        orderJsonFixture(orderId: 'failed-1', orderStatus: 'Failed'),
        orderJsonFixture(orderId: 'usdt-1', orderType: 'Sell USDT'),
        orderJsonFixture(
          orderId: 'bad-1',
          overrides: const {'createdAt': 'not-a-date'},
        ),
        orderJsonFixture(orderId: 'good-1'),
      ]);

      final result = await repository.getOrders();

      expect(result.map((o) => o.orderId), [
        'expired-1',
        'failed-1',
        'usdt-1',
        'good-1',
      ]);
      // The server never sends an order status 'Failed'.
      expect(result[1].orderStatus, OrderStatus.unknown);
      expect(result[2].orderType, OrderType.sellUsdt);
      expect(result[2], isA<GenericOrder>());
    });

    test('asks the server for one type and one page', () async {
      stubOrders([orderJsonFixture(orderId: 'buy-2')]);

      final result = await repository.getOrders(
        type: OrderType.buy,
        offset: 1,
        limit: 1,
      );

      expect(result.map((o) => o.orderId), ['buy-2']);
      final request =
          verify(() => orders.listOrderSummaries(captureAny())).captured.single
              as bbx.ListRequest;
      expect(request.toParams(), {
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'paginator': {'page': 2, 'pageSize': 1},
        'filters': {
          'orderType': ['Buy Bitcoin'],
        },
      });
    });

    test('an offset that is not a whole page returns no orders', () async {
      stubOrders([orderJsonFixture()]);

      expect(await repository.getOrders(offset: 1, limit: 2), isEmpty);
      verifyNever(() => orders.listOrderSummaries(any()));
    });

    test('no stored key returns no orders and calls nothing', () async {
      when(() => apiKeys.get(isTestnet: true)).thenAnswer((_) async => null);

      expect(await repository.getOrders(), isEmpty);
      expect(await repository.getOrderByTxId('txid'), isNull);
      verifyNever(() => orders.listOrderSummaries(any()));
    });

    test('a failed list returns no orders', () async {
      when(() => orders.listOrderSummaries(any())).thenAnswer(
        (_) async => bbx.ApiResult.apiFailure(
          error: const bbx.ApiError(serverMessage: 'x'),
        ),
      );

      expect(await repository.getOrders(), isEmpty);
      expect(await repository.getOrderByTxId('txid'), isNull);
    });

    test('finds an order by its own or its payjoin transaction', () async {
      stubOrders([
        orderJsonFixture(orderId: 'good-1'),
        orderJsonFixture(
          orderId: 'good-2',
          overrides: const {'bitcoinTransactionId': 'txid-2'},
        ),
        orderJsonFixture(
          orderId: 'payjoin-1',
          overrides: const {
            'payjoinDetails': {'txid': 'txid-pj'},
          },
        ),
      ]);

      expect((await repository.getOrderByTxId('txid-2'))?.orderId, 'good-2');
      expect(
        (await repository.getOrderByTxId('txid-pj'))?.orderId,
        'payjoin-1',
      );
      expect(await repository.getOrderByTxId('txid-absent'), isNull);
    });

    test('reads one order', () async {
      when(() => orders.getOrderSummary(orderId: 'usdt-1')).thenAnswer(
        (_) async => bbx.ApiResult.success(
          data: bbx.OrderSummaryModel.fromJson(
            orderJsonFixture(orderId: 'usdt-1', orderType: 'Sell USDT'),
            fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks,
          ),
        ),
      );

      final order = await repository.getOrder('usdt-1');

      expect(order.orderType, OrderType.sellUsdt);
    });

    test('a failed single read throws', () async {
      when(() => orders.getOrderSummary(orderId: 'x')).thenAnswer(
        (_) async => bbx.ApiResult.apiFailure(
          error: const bbx.ApiError(serverMessage: 'x'),
        ),
      );

      await expectLater(repository.getOrder('x'), throwsException);
    });
  });

  group('order rejections', () {
    Map<String, dynamic> limit(
      Object amount,
      String currencyCode,
      String conditionalOperator,
    ) => {
      'amount': amount,
      'currencyCode': currencyCode,
      'conditionalOperator': conditionalOperator,
    };

    void rejectBuyWith(Map<String, dynamic> data) => failBuyWith(
      bbx.ApiError(serverMessage: 'rejected', rpcErrorData: data),
    );

    final genericError = throwsA(
      isA<Exception>()
          .having(
            (e) => e,
            'min',
            isNot(isA<BullBitcoinApiMinAmountException>()),
          )
          .having(
            (e) => e,
            'max',
            isNot(isA<BullBitcoinApiMaxAmountException>()),
          ),
    );

    test('a string amount in the single reason shape is read', () async {
      rejectBuyWith({
        'reason': {'limit': limit('0.0001', 'BTC', 'GREATER_THAN_OR_EQUAL')},
      });

      await expectLater(
        placeBuy(),
        throwsA(
          isA<BullBitcoinApiMinAmountException>()
              .having((e) => e.minAmount, 'minAmount', 0.0001)
              .having((e) => e.currency, 'currency', 'BTC'),
        ),
      );
    });

    test('rejected options without a limit are the generic error', () async {
      rejectBuyWith({
        'details': <dynamic>[null, null],
        'apiError': {'code': 'ERR_ORD_PO404'},
      });
      await expectLater(placeBuy(), genericError);

      rejectBuyWith({
        'reason': {'accessDescription': 'e-Transfer', 'amount': '5'},
      });
      await expectLater(placeBuy(), genericError);
    });

    test(
      'a limit that is neither a minimum nor a maximum is generic',
      () async {
        rejectBuyWith({
          'reason': {'limit': limit(20, 'CAD', 'NOT_EQUAL')},
        });

        await expectLater(placeBuy(), genericError);
      },
    );

    test('a sell rejection is mapped the same way', () async {
      when(() => orders.sellToBalance(params: any(named: 'params'))).thenAnswer(
        (_) async => bbx.ApiResult.apiFailure(
          error: bbx.ApiError(
            serverMessage: 'rejected',
            rpcErrorData: {
              'reason': {'limit': limit(30, 'EUR', 'GREATER_THAN_OR_EQUAL')},
            },
          ),
        ),
      );

      await expectLater(
        repository.placeSellOrder(
          orderAmount: const FiatAmount(1),
          currency: FiatCurrency.eur,
          network: OrderBitcoinNetwork.bitcoin,
        ),
        throwsA(isA<BullBitcoinApiMinAmountException>()),
      );
    });
  });

  group('EUR Sell payout requests', () {
    Future<FiatPaymentOrder> placeSellToRecipient(
      SepaPaymentProcessor processor, {
      OrderAmount orderAmount = const FiatAmount(100),
      bool usePayjoin = false,
    }) => repository.placeSellToRecipientOrderV2(
      orderAmount: orderAmount,
      recipientId: 'own-account',
      paymentProcessor: processor,
      network: OrderBitcoinNetwork.bitcoin,
      usePayjoin: usePayjoin,
    );

    void failSellToRecipientWith(bbx.ApiError error) {
      when(
        () => orders.sellToRecipient(params: any(named: 'params')),
      ).thenAnswer((_) async => bbx.ApiResult.apiFailure(error: error));
    }

    test('keeps rejection codes without exposing account details', () async {
      failSellToRecipientWith(
        const bbx.ApiError(
          code: '-32603',
          serverMessage: 'Account details must stay out of diagnostics',
          rpcErrorData: {
            'apiError': {
              'code': 'ERR_ORD_PO404',
              'message': 'Account details must stay out of diagnostics',
            },
          },
        ),
      );

      await expectLater(
        placeSellToRecipient(SepaPaymentProcessor.regular),
        throwsA(
          isA<BullBitcoinApiOrderException>()
              .having((error) => error.apiCode, 'apiCode', 'ERR_ORD_PO404')
              .having(
                (error) => error.toString(),
                'diagnostics',
                isNot(contains('Account details')),
              ),
        ),
      );
    });

    for (final processor in SepaPaymentProcessor.values) {
      test(
        'bank payout sends ${processor.name} processor and recipient',
        () async {
          when(
            () => orders.sellToRecipient(params: any(named: 'params')),
          ).thenAnswer(
            (_) async => bbx.ApiResult.success(
              data: bbx.OrderSummaryModel.fromJson({
                'orderId': 'order-1',
                'orderType': 'Fiat Payment',
                'orderNumber': 1,
                'payinAmount': 0.001,
                'payinCurrency': 'BTC',
                'payoutAmount': 100.0,
                'payoutCurrency': 'EUR',
                'orderStatus': 'In progress',
                'payinStatus': 'Awaiting payment',
                'payoutStatus': 'Not started',
                'createdAt': '2026-07-28T12:00:00.000Z',
                'message': {'code': '', 'message': ''},
                'payinMethod': 'Bitcoin On-Chain',
                'payoutMethod': 'Bitcoin On-Chain',
              }),
            ),
          );

          final order = await placeSellToRecipient(
            processor,
            orderAmount: const BitcoinAmount(0.001),
            usePayjoin: true,
          );

          expect(order, isA<FiatPaymentOrder>());
          final payload =
              verify(
                    () => orders.sellToRecipient(
                      params: captureAny(named: 'params'),
                    ),
                  ).captured.single
                  as bbx.SellToRecipientPayload;
          expect(payload.toParams(), {
            'bitcoinAmount': 0.001,
            'bitcoinNetwork': 'bitcoin',
            'recipientId': 'own-account',
            'paymentProcessor': processor == SepaPaymentProcessor.confidential
                ? 'CONFIDENTIAL_SEPA'
                : 'REGULAR_SEPA',
            'usePayjoin': true,
          });
        },
      );
    }

    test(
      'maps inactive confidential recipient to the activation failure',
      () async {
        failSellToRecipientWith(
          const bbx.ApiError(
            serverMessage: 'Recipient not activated',
            rpcErrorData: {
              'apiError': {'code': 'ERR_ORD_CSRCP400'},
            },
          ),
        );

        await expectLater(
          placeSellToRecipient(SepaPaymentProcessor.confidential),
          throwsA(isA<BullBitcoinApiConfidentialSepaNotActivatedException>()),
        );
      },
    );
  });

  test('an uncertain create keeps its mapped failure', () async {
    failBuyWith(const bbx.ApiError(kind: bbx.ApiErrorKind.outcomeUnknown));
    await expectLater(
      placeBuy(),
      throwsA(
        isA<BbxApiException>().having(
          (e) => e.failure,
          'failure',
          isA<ExchangeApiOutcomeUnknownFailure>(),
        ),
      ),
    );
  });

  group('ApiError helpers', () {
    test('classify transport failures', () {
      expect(
        const bbx.ApiError(
          serverMessage: 'x',
          kind: bbx.ApiErrorKind.network,
        ).isUnreachable,
        isTrue,
      );
      expect(
        const bbx.ApiError(
          serverMessage: 'x',
          kind: bbx.ApiErrorKind.network,
        ).isUnreachable,
        isTrue,
      );
      expect(
        const bbx.ApiError(serverMessage: 'x', httpStatus: 401).httpStatus,
        401,
      );
      expect(
        const bbx.ApiError(
          serverMessage: 'x',
          kind: bbx.ApiErrorKind.unauthenticated,
          code: 'ERR_API_KEY_MISSING',
        ).isApiKeyMissing,
        isTrue,
      );
    });

    test('BbxApiException never prints the message', () {
      const error = bbx.ApiError(serverMessage: 'answer: secret', code: 'C1');
      expect(BbxApiException(error).toString(), isNot(contains('secret')));
    });
  });
}

class _MockBbxApi extends Mock implements bbx.BbxApi {}
