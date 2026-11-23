import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'bbx_api_test_http.dart';
import 'order_json_fixture.dart';

final class _HeldResponse implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('order requests never select credentials for another backend', () async {
    final exchange = exchangeWithTransportForTesting(
      readSession: () async => const Ok((
        environment: ExchangeEnvironment.testnet,
        epoch: 0,
        apiKey: 'synthetic-session-key',
      )),
      openClient: (_, _) => fail('A mismatched backend must not open a client'),
    );
    expect(
      await exchange.orders(ExchangeEnvironment.mainnet).getOrders(),
      isA<Err<List<Order>, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOperationStaleFailure>(),
      ),
    );
  });

  test('a current HTTP 401 is not an empty order history', () async {
    final http = FakeBbxHttp(status: 401);
    final orders = testExchangeOrders(http);
    expect(
      await orders.getOrders(),
      isA<Err<List<Order>, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
    expect(http.requests, hasLength(1));
  });

  for (final status in [200, 401]) {
    test(
      'an order write completing with $status cannot cross an epoch',
      () async {
        var epoch = 0;
        final http = _HeldResponse();
        final exchange = exchangeWithTransportForTesting(
          readSession: () async => Ok((
            environment: ExchangeEnvironment.testnet,
            epoch: epoch,
            apiKey: 'synthetic-session-key',
          )),
          openClient: (endpoint, readKey) => bbxForTesting(
            endpoint: endpoint.toString(),
            adapter: http,
            readActiveApiKey: readKey,
          ),
        );
        final pending = exchange
            .orders(ExchangeEnvironment.testnet)
            .confirmBuyOrder('order-1');
        await http.started.future;
        epoch++;
        http.response.complete(
          ResponseBody.fromString(
            jsonEncode({'result': orderJsonFixture()}),
            status,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        expect(
          await pending,
          isA<Err<BuyOrder, ExchangeFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<ExchangeOperationStaleFailure>(),
          ),
        );
        expect(http.requests, hasLength(1));
      },
    );
  }

  for (final environment in ExchangeEnvironment.values) {
    test('default wallet writes use the ${environment.name} session', () async {
      final endpoints = <Uri>[];
      final http = FakeBbxHttp(
        body: {
          'result': {
            'element': {
              'recipientId': 'synthetic',
              'recipientType': 'OUT_BITCOIN_ADDRESS',
            },
          },
        },
      );
      final exchange = exchangeWithTransportForTesting(
        readSession: () async => Ok((
          environment: environment,
          epoch: 0,
          apiKey: 'synthetic-session-key',
        )),
        openClient: (endpoint, readKey) {
          endpoints.add(endpoint);
          return bbxForTesting(
            endpoint: endpoint.toString(),
            adapter: http,
            readActiveApiKey: readKey,
          );
        },
      );
      final result = await exchange.deleteDefaultWallet(
        recipientId: 'synthetic',
        walletType: WalletAddressType.bitcoin,
        address: 'synthetic-address',
      );
      expect(result, isA<Ok<void, ExchangeFailure>>());
      expect(endpoints.single.host, startsWith(environment.name));
    });
  }
}
